"""
FILE: backend/app/services/model_submission/service.py
"""

import hashlib
import io
import os
import tarfile
import uuid

from fastapi import UploadFile

from app.core.exceptions import NotFoundError, ValidationError
from app.core.phase_guard import phase_guard
from app.models import Model
from app.storage.minio_client import storage_service

from .repository import ModelSubmissionRepository

# Maximum allowed Docker image size (bytes) — 500 MB.
_MAX_SIZE_BYTES = 500 * 1024 * 1024

# Accepted content types for model archives / Docker images.
_ALLOWED_CONTENT_TYPES = {
    "application/octet-stream",
    "application/zip",
    "application/x-zip-compressed",
    "application/x-tar",
    "application/gzip",
    "application/x-gzip",
    "application/x-bzip2",
}


class ModelSubmissionService:
    def __init__(self, repository: ModelSubmissionRepository):
        self.repository = repository

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _assert_team_in_competition(self, team_id: int, competition_id: int) -> None:
        if not self.repository.team_belongs_to_competition(team_id, competition_id):
            raise ValidationError("Team does not belong to this competition")

    def _validate_file(self, file: UploadFile, contents: bytes) -> None:
        if len(contents) > _MAX_SIZE_BYTES:
            raise ValidationError(
                f"Model file exceeds the 500 MB limit "
                f"(received {len(contents) / (1024 * 1024):.1f} MB)"
            )
        content_type = (file.content_type or "").lower()
        if content_type not in _ALLOWED_CONTENT_TYPES:
            raise ValidationError(
                f"Unsupported file type: '{file.content_type}'. "
                f"Upload a Docker image archive (.tar, .tar.gz) or a zip archive."
            )

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def submit_model(
        self,
        team_id: int,
        competition_id: int,
        file: UploadFile,
        db,  # Session — passed for phase guard
    ) -> Model:
        """
        Validate, store, and record a model submission.

        Phase restriction: only allowed during 'evaluation' phase.
        """
        # 1. Phase guard — model submissions only in evaluation phase.
        phase_guard.assert_phase(
            db,
            competition_id,
            allowed_phases=["evaluation"],
            action_description="model submission",
        )

        # 2. Team belongs to competition.
        self._assert_team_in_competition(team_id, competition_id)

        # 3. Read and validate file.
        contents = await file.read()
        self._validate_file(file, contents)

        # 3.5. Calculate hash and validate structure
        model_hash = hashlib.sha256(contents).hexdigest()
        
        ext = os.path.splitext(file.filename or "model.tar")[1] or ".tar"
        
        if ext in [".tar", ".tar.gz", ".tgz"]:
            try:
                # Basic check to ensure it's actually a tarball
                with tarfile.open(fileobj=io.BytesIO(contents), mode="r:gz" if ext in [".tar.gz", ".tgz"] else "r") as tar:
                    tar.getmembers()
            except tarfile.TarError:
                raise ValidationError(f"File validation failed: The uploaded file is not a valid {ext} archive.")

        # 4. Persist to storage (MinIO / local fallback).
        object_name = f"models/comp_{competition_id}/team_{team_id}/{uuid.uuid4()}{ext}"
        storage_service.upload_file(contents, object_name)

        # 5. Create DB record.
        model = self.repository.create(
            team_id=team_id,
            competition_id=competition_id,
            docker_img_filepath=object_name,
            model_hash=model_hash,
        )
        return model

    def get_model(self, model_id: int) -> Model:
        model = self.repository.find_by_id(model_id)
        if not model:
            raise NotFoundError("Model not found")
        return model

    def list_by_team(self, team_id: int) -> list[Model]:
        team = self.repository.find_team(team_id)
        if not team:
            raise NotFoundError("Team not found")
        return self.repository.find_by_team(team_id)

    def list_by_competition(self, competition_id: int) -> list[Model]:
        comp = self.repository.find_competition(competition_id)
        if not comp:
            raise NotFoundError("Competition not found")
        return self.repository.find_by_competition(competition_id)

    def delete_model(self, model_id: int) -> int:
        model = self.get_model(model_id)
        # Best-effort delete from storage.
        try:
            storage_service.delete_file(model.docker_img_filepath)
        except Exception:
            pass
        self.repository.delete(model)
        return model_id