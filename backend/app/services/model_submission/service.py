import ast
import hashlib
import os
import zipfile
from datetime import datetime
from io import BytesIO
from uuid import UUID, uuid4

from fastapi import UploadFile

from app.core.exceptions import NotFoundError, ValidationError
from app.models.model_model import ModelStatus
from app.storage.minio_client import storage_service

from .repository import ModelSubmissionRepository

# Mapping of model format → accepted file extensions inside the model/ dir
MODEL_FORMAT_EXTENSIONS = {
    "tensorflow": [".pb", ".h5"],
    "pytorch": [".pt", ".pth"],
    "sklearn": [".pkl", ".pickle"],
    "keras": [".h5"],
    "onnx": [".onnx"],
}

# Default spec used when the organizer has not set one yet
DEFAULT_MODEL_SPEC = {
    "required_files": ["Dockerfile", "inference.py", "requirements.txt"],
    "model_dir": "model",
    "data_dir": "data",
    "inference_function": "predict",
    "allowed_model_formats": ["pytorch", "tensorflow", "sklearn", "keras", "onnx"],
    "required_packages": [],
    "max_size_mb": 500.0,
    "python_version_min": None,
}


class ModelSubmissionService:
    """
    Service for Docker-based model submission business logic.

    Participants submit a .zip Docker build context with this structure:
        submission.zip/
        ├── Dockerfile
        ├── inference.py          ← must contain the organizer-defined predict() function
        ├── requirements.txt
        ├── model/                ← model file(s) in a supported format
        └── data/                 ← empty; dataset is injected here at evaluation time
    """

    DEFAULT_MODEL_SPEC = DEFAULT_MODEL_SPEC

    def __init__(self, repository: ModelSubmissionRepository):
        self.repository = repository

    # ------------------------------------------------------------------ #
    #  Public entry point                                                  #
    # ------------------------------------------------------------------ #

    async def submit_model(
        self,
        team_id: int,
        competition_id: int,
        file: UploadFile,
        metadata: dict,
        user_id: int,
    ) -> dict:
        """
        Full submission flow:
          1. Enforce .zip extension
          2. Fetch organizer's model_spec from config
          3. Validate the zip against that spec
          4. SHA-256 deduplicate
          5. Store zip in MinIO / local fallback
          6. Persist model record + metadata in DB
          7. Auto-schedule for evaluation
        """
        # 1. Must be a zip
        if not file.filename or not file.filename.lower().endswith(".zip"):
            raise ValidationError(
                "Submission must be a .zip Docker build context. "
                "Expected structure: Dockerfile, inference.py, requirements.txt, model/, data/"
            )

        file_content = await file.read()
        if not file_content:
            raise ValidationError("Uploaded file is empty.")

        # 2. Validate team eligibility and competition phase
        self._validate_team_eligibility(team_id, competition_id, user_id)
        self._validate_submission_phase(competition_id)

        # 3. Fetch organizer's spec (falls back to defaults if not set)
        spec = self._get_model_spec(competition_id)

        # 4. Validate the zip contents against the spec
        validation_result = self.validate_docker_submission(file_content, spec)

        # 5. SHA-256 deduplication
        model_hash = hashlib.sha256(file_content).hexdigest()
        existing = self.repository.find_by_hash(model_hash)
        if existing:
            raise ValidationError(
                f"A submission with identical content already exists "
                f"(model ID: {existing.id}). Modify your submission before resubmitting."
            )

        # 6. Store zip
        size_mb = len(file_content) / (1024 * 1024)
        storage_path = self._store_submission(file.filename, file_content)

        # 7. Persist
        latest = self.repository.find_latest_by_team(team_id, competition_id)
        next_version: int = (latest.version + 1) if latest else 1  # type: ignore[operator]

        model = self.repository.save_model_record(
            team_id=team_id,
            competition_id=competition_id,
            filename=file.filename,
            storage_path=storage_path,
            model_hash=model_hash,
            format=validation_result["detected_format"],
            framework_version=metadata.get("framework_version", "unknown"),
            size_mb=size_mb,
            submitted_by=user_id,
            version=next_version,
        )

        self.repository.save_model_metadata(model.id, metadata)  # type: ignore[arg-type]

        # 8. Auto-schedule
        config = self.repository.find_competition_config(competition_id)
        protocol = getattr(config, 'evaluation', None) if config else None
        protocol = str(protocol) if protocol else "standard"
        self._schedule_for_evaluation(model.id, protocol)

        return {
            "id": str(model.id),
            "team_id": model.team_id,
            "competition_id": model.competition_id,
            "filename": model.filename,
            "format": validation_result["detected_format"],
            "version": model.version,
            "status": ModelStatus.SCHEDULED.value,
            "submitted_at": model.submitted_at,
            "submitted_by": model.submitted_by,
            "message": (
                f"Submission accepted. Version {next_version}. "
                f"Detected model format: {validation_result['detected_format']}."
            ),
        }

    # ------------------------------------------------------------------ #
    #  Eligibility & phase guards                                          #
    # ------------------------------------------------------------------ #

    def _validate_team_eligibility(
        self, team_id: int, competition_id: int, user_id: int
    ) -> None:
        """
        Ensure:
          - The team exists
          - The team belongs to this competition
          - The submitting user is a member of that team
        """
        team = self.repository.find_team(team_id)
        if not team:
            raise ValidationError(f"Team {team_id} does not exist.")

        if team.comp_id != competition_id:
            raise ValidationError(
                f"Team {team_id} does not belong to competition {competition_id}."
            )

        # Check user's email is in team's user_emails
        user = self.repository.find_user_by_id(user_id)
        if not user:
            raise ValidationError("User not found.")
        user_email = user.email.strip().lower()
        emails_dict = team.user_emails or {}
        if user_email not in {k.lower() for k in emails_dict.keys()}:
            raise ValidationError(
                f"You are not a member of team {team_id}. "
                "Only team members may submit models."
            )

    def _validate_submission_phase(self, competition_id: int) -> None:
        """
        Ensure the competition is in the 'evaluation' phase.
        Submissions are only accepted during that phase.
        """
        phase_log = self.repository.find_phase(competition_id)
        if not phase_log:
            raise ValidationError(
                "Competition phase has not been initialised yet. Contact the organizer."
            )

        current = str(phase_log.current_phase).lower().strip()
        if current != "evaluation":
            raise ValidationError(
                f"Model submissions are only accepted during the evaluation phase. "
                f"Current phase: '{current}'."
            )

    # ------------------------------------------------------------------ #
    #  Top-level Docker submission validator                               #
    # ------------------------------------------------------------------ #

    def validate_docker_submission(self, zip_bytes: bytes, spec: dict) -> dict:
        """
        Validate a .zip Docker build context against the organizer's spec.
        Returns a dict with validation details or raises ValidationError.
        """
        # Open zip
        try:
            zf = zipfile.ZipFile(BytesIO(zip_bytes))
        except zipfile.BadZipFile:
            raise ValidationError("File is not a valid zip archive.")

        names = zf.namelist()  # all paths inside the zip

        # Run each check; collect results
        self._check_size(zip_bytes, spec)
        self._check_required_files(names, spec)
        detected_format = self._check_model_dir(zf, names, spec)
        self._check_data_dir(names, spec)
        self._check_inference_py(zf, names, spec)
        self._check_requirements_txt(zf, names, spec)
        self._check_dockerfile(zf, names)

        zf.close()
        return {"valid": True, "detected_format": detected_format}

    # ------------------------------------------------------------------ #
    #  Individual check helpers                                            #
    # ------------------------------------------------------------------ #

    def _check_size(self, zip_bytes: bytes, spec: dict) -> None:
        """Reject if zip exceeds the organizer's max_size_mb limit."""
        max_mb = spec.get("max_size_mb", DEFAULT_MODEL_SPEC["max_size_mb"])
        actual_mb = len(zip_bytes) / (1024 * 1024)
        if actual_mb > max_mb:
            raise ValidationError(
                f"Submission is {actual_mb:.1f} MB, exceeds the limit of {max_mb} MB."
            )

    def _check_required_files(self, names: list, spec: dict) -> None:
        """
        Ensure every file listed in spec['required_files'] is present.
        Supports both flat paths ('Dockerfile') and nested ('subdir/Dockerfile').
        """
        required = spec.get("required_files", DEFAULT_MODEL_SPEC["required_files"])
        # Normalise zip names to their base filename for flexible matching
        base_names = {os.path.basename(n) for n in names}

        missing = []
        for req in required:
            req_base = os.path.basename(req)
            # Accept exact path match OR base-name match
            if req not in names and req_base not in base_names:
                missing.append(req)

        if missing:
            raise ValidationError(
                f"Missing required files in submission: {', '.join(missing)}. "
                f"Required: {', '.join(required)}"
            )

    def _check_model_dir(self, zf: zipfile.ZipFile, names: list, spec: dict) -> str:
        """
        Verify the model/ directory exists and contains at least one file
        whose extension matches one of the organizer's allowed_model_formats.
        Returns the detected format string (e.g. 'pytorch').
        """
        model_dir = spec.get("model_dir", DEFAULT_MODEL_SPEC["model_dir"]).rstrip("/")
        allowed_formats = spec.get(
            "allowed_model_formats", DEFAULT_MODEL_SPEC["allowed_model_formats"]
        )

        # Collect all extensions inside model_dir/
        model_files = [
            n for n in names if n.startswith(model_dir + "/") and not n.endswith("/")
        ]

        if not model_files:
            raise ValidationError(
                f"Submission must contain a '{model_dir}/' directory with the model file(s). "
                f"Supported formats: {', '.join(allowed_formats)}"
            )

        # Build the full set of allowed extensions from the allowed formats
        allowed_extensions: set[str] = set()
        for fmt in allowed_formats:
            allowed_extensions.update(MODEL_FORMAT_EXTENSIONS.get(fmt, []))

        detected_format = None
        for model_file in model_files:
            ext = os.path.splitext(model_file)[1].lower()
            for fmt, exts in MODEL_FORMAT_EXTENSIONS.items():
                if ext in exts and fmt in allowed_formats:
                    detected_format = fmt
                    break
            if detected_format:
                break

        if not detected_format:
            found_exts = {os.path.splitext(f)[1].lower() for f in model_files}
            raise ValidationError(
                f"No recognised model file found in '{model_dir}/'. "
                f"Found extensions: {found_exts}. "
                f"Allowed formats for this competition: {allowed_formats}"
            )

        return detected_format

    def _check_data_dir(self, names: list, spec: dict) -> None:
        """
        Verify the data/ directory exists (it should be empty — dataset is injected later).
        Accepts either an explicit empty-dir entry ('data/') or any file under 'data/'.
        """
        data_dir = spec.get("data_dir", DEFAULT_MODEL_SPEC["data_dir"]).rstrip("/")

        has_data_dir = any(
            n == data_dir + "/" or n.startswith(data_dir + "/") for n in names
        )
        if not has_data_dir:
            raise ValidationError(
                f"Submission must contain an empty '{data_dir}/' directory. "
                "This is where the competition dataset will be injected at evaluation time."
            )

    def _check_inference_py(self, zf: zipfile.ZipFile, names: list, spec: dict) -> None:
        """
        Parse inference.py with Python's ast module and verify that the
        organizer-defined inference function (default: 'predict') is defined.
        """
        required_fn = spec.get(
            "inference_function", DEFAULT_MODEL_SPEC["inference_function"]
        )

        # Find inference.py regardless of nesting
        inference_path = next(
            (n for n in names if os.path.basename(n) == "inference.py"), None
        )
        if not inference_path:
            raise ValidationError("inference.py not found in submission.")

        source = zf.read(inference_path).decode("utf-8", errors="replace")

        # Parse and look for the required top-level function definition
        try:
            tree = ast.parse(source)
        except SyntaxError as exc:
            raise ValidationError(f"inference.py has a syntax error: {exc}")

        function_names = {
            node.name for node in ast.walk(tree) if isinstance(node, ast.FunctionDef)
        }

        if required_fn not in function_names:
            raise ValidationError(
                f"inference.py must define a function named '{required_fn}'. "
                f"Found functions: {sorted(function_names) or 'none'}"
            )

    def _check_requirements_txt(
        self, zf: zipfile.ZipFile, names: list, spec: dict
    ) -> None:
        """
        Verify that every package in spec['required_packages'] appears
        in requirements.txt (case-insensitive, strips version pins).
        """
        required_pkgs = spec.get(
            "required_packages", DEFAULT_MODEL_SPEC["required_packages"]
        )
        if not required_pkgs:
            return  # Nothing to check

        req_path = next(
            (n for n in names if os.path.basename(n) == "requirements.txt"), None
        )
        if not req_path:
            raise ValidationError(
                "requirements.txt not found. "
                f"It must list at least: {', '.join(required_pkgs)}"
            )

        content = zf.read(req_path).decode("utf-8", errors="replace")

        # Parse each non-blank, non-comment line; strip version specifiers
        listed_pkgs = set()
        for line in content.splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            # Strip version pin: numpy>=1.20 → numpy
            pkg = (
                line.split("=")[0]
                .split(">")[0]
                .split("<")[0]
                .split("!")[0]
                .split("[")[0]
                .strip()
                .lower()
            )
            listed_pkgs.add(pkg)

        missing = [p for p in required_pkgs if p.lower() not in listed_pkgs]
        if missing:
            raise ValidationError(
                f"requirements.txt is missing required packages: {', '.join(missing)}. "
                f"Add them to requirements.txt and resubmit."
            )

    def _check_dockerfile(self, zf: zipfile.ZipFile, names: list) -> None:
        """
        Basic Dockerfile sanity checks:
          - Must exist (already checked in required_files, but defensive)
          - Must contain a FROM instruction
          - Must contain a CMD or ENTRYPOINT instruction
        """
        dockerfile_path = next(
            (n for n in names if os.path.basename(n) == "Dockerfile"), None
        )
        if not dockerfile_path:
            raise ValidationError("Dockerfile not found in submission.")

        content = zf.read(dockerfile_path).decode("utf-8", errors="replace").upper()
        lines = [
            ln.strip()
            for ln in content.splitlines()
            if ln.strip() and not ln.strip().startswith("#")
        ]

        has_from = any(ln.startswith("FROM") for ln in lines)
        has_entry = any(
            ln.startswith("CMD") or ln.startswith("ENTRYPOINT") for ln in lines
        )

        if not has_from:
            raise ValidationError(
                "Dockerfile must contain a FROM instruction (base image). "
                "Example: FROM python:3.9-slim"
            )
        if not has_entry:
            raise ValidationError(
                "Dockerfile must contain a CMD or ENTRYPOINT instruction "
                'that runs inference. Example: CMD ["python", "inference.py"]'
            )

    # ------------------------------------------------------------------ #
    #  Config spec helpers                                                 #
    # ------------------------------------------------------------------ #

    def _get_model_spec(self, competition_id: int) -> dict:
        """
        Load the organizer's model_spec from config.
        Falls back to DEFAULT_MODEL_SPEC if not configured yet.
        """
        config = self.repository.find_competition_config(competition_id)
        if config is not None:
            raw_spec = config.model_spec  # type: ignore[assignment]
            if isinstance(raw_spec, dict) and len(raw_spec) > 0:
                return {**DEFAULT_MODEL_SPEC, **raw_spec}
        return DEFAULT_MODEL_SPEC

    # ------------------------------------------------------------------ #
    #  Storage & scheduling helpers                                        #
    # ------------------------------------------------------------------ #

    def _store_submission(self, original_filename: str, content: bytes) -> str:
        """Upload the zip to MinIO (or local fallback) and return the storage path."""
        unique_name = f"{uuid4()}.zip"
        object_name = f"models/{unique_name}"
        storage_service.upload_file(content, object_name)
        return object_name

    def _schedule_for_evaluation(self, model_id, protocol: str) -> None:
        self.repository.update_status(model_id, ModelStatus.SCHEDULED)
        self.repository.update_scheduled_at(model_id)

        from app.core.database import SessionLocal
        from app.services.evaluation_orchestration.repository import (
            EvaluationOrchestrationRepository,
        )
        from app.services.evaluation_orchestration.service import (
            EvaluationOrchestrationService,
        )

        db = SessionLocal()
        try:
            eval_service = EvaluationOrchestrationService(
                EvaluationOrchestrationRepository(db)
            )
            eval_service.scheduleEvaluation(
                model_id=model_id,
                protocol=protocol,
            )
        finally:
            db.close()

    # ------------------------------------------------------------------ #
    #  Read helpers (used by controller)                                   #
    # ------------------------------------------------------------------ #

    def get_model_by_id(self, model_id: UUID):
        model = self.repository.get_model_with_metadata(model_id)
        if not model:
            raise NotFoundError(f"Model {model_id} not found")
        return model

    def get_models_by_competition(
        self, comp_id: int, page: int = 1, limit: int = 20
    ) -> dict:
        skip = (page - 1) * limit
        models, total = self.repository.find_by_competition(comp_id, skip, limit)
        return {"models": models, "total": total, "page": page, "limit": limit}

    def get_team_models(self, team_id: int, page: int = 1, limit: int = 20) -> dict:
        """List all models submitted by a team across all competitions."""
        skip = (page - 1) * limit
        models, total = self.repository.find_all_by_team(team_id, skip, limit)
        return {"models": models, "total": total, "page": page, "limit": limit}

    def get_team_model_history(
        self, team_id: int, comp_id: int, page: int = 1, limit: int = 20
    ) -> dict:
        skip = (page - 1) * limit
        models, total = self.repository.find_by_team(team_id, comp_id, skip, limit)
        _, versions = self.repository.get_team_submission_history(team_id, comp_id)
        return {
            "models": models,
            "total": total,
            "page": page,
            "limit": limit,
            "versions": versions,
        }

    def schedule_model_for_evaluation(self, model_id: UUID) -> dict:
        model = self.repository.find_by_id(model_id)
        if not model:
            raise NotFoundError(f"Model {model_id} not found")

        if model.status not in [ModelStatus.RECEIVED, ModelStatus.VALIDATED]:
            raise ValidationError(
                f"Cannot schedule a model in '{model.status.value}' status. "
                "Must be RECEIVED or VALIDATED."
            )

        self.repository.update_status(model_id, ModelStatus.SCHEDULED)
        self.repository.update_scheduled_at(model_id)

        return {
            "model_id": str(model.id),
            "scheduled": True,
            "evaluation_status": ModelStatus.SCHEDULED.value,
            "scheduled_at": datetime.utcnow(),
        }

    def delete_model(self, model_id: UUID) -> bool:
        model = self.repository.find_by_id(model_id)
        if not model:
            raise NotFoundError(f"Model {model_id} not found")

        try:
            storage_service.delete_file(str(model.storage_path))
        except Exception as exc:
            print(f"Warning: could not delete file from storage: {exc}")

        return self.repository.delete_model(model_id)

    def get_competition_model_spec(self, competition_id: int) -> dict:
        """Return the active model_spec for a competition (useful for participants to preview)."""
        return self._get_model_spec(competition_id)
