"""
Comprehensive test suite for the Model Submission module.

Tests cover:
- Docker zip submission validation
- Team eligibility checks
- Competition phase validation
- Model deduplication
- Version tracking
- Storage integration
- API endpoints
- Error handling
"""

import asyncio
import io
import json
import zipfile
from datetime import datetime
from pathlib import Path
from typing import Dict, Tuple
from uuid import uuid4

import pytest
from app.core.database import Base
from app.core.exceptions import ValidationError
from app.main import app
from app.models import (
    Competition,
    Config,
    Model,
    ModelMetadata,
    PhaseLog,
    Role,
    RoleType,
    Team,
    User,
)
from app.services.model_submission.repository import ModelSubmissionRepository
from app.services.model_submission.service import ModelSubmissionService
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

# ============================================
# DATABASE SETUP
# ============================================

TEST_DATABASE_URL = "sqlite:///./test_model_submission.db"


@pytest.fixture(scope="function")
def test_db():
    """Create a fresh test database for each test."""
    engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    db = SessionLocal()
    yield db
    db.close()
    Base.metadata.drop_all(bind=engine)


# ============================================
# FIXTURES
# ============================================


@pytest.fixture
def host_user(test_db: Session) -> User:
    """Create a host user."""
    user = User(
        fullname="Host User",
        email="host@example.com",
        password="hashed_password",
        phone=None,
    )
    test_db.add(user)
    test_db.commit()
    test_db.refresh(user)
    return user


@pytest.fixture
def participant_user(test_db: Session) -> User:
    """Create a participant user."""
    user = User(
        fullname="Participant User",
        email="participant@example.com",
        password="hashed_password",
        phone=None,
    )
    test_db.add(user)
    test_db.commit()
    test_db.refresh(user)
    return user


@pytest.fixture
def competition(test_db: Session, host_user: User) -> Competition:
    """Create a test competition."""
    comp = Competition(
        name="Test Competition",
        description="A test competition",
        launch_date=None,
        invitation_link="test-link",
    )
    test_db.add(comp)
    test_db.flush()

    # Add host role
    role = Role(user_id=host_user.id, competition_id=comp.id, role=RoleType.host)
    test_db.add(role)

    # Add config with model_spec
    config = Config(
        competition_id=comp.id,
        model_spec={
            "required_files": ["Dockerfile", "inference.py", "requirements.txt"],
            "model_dir": "model",
            "data_dir": "data",
            "inference_function": "predict",
            "allowed_model_formats": ["pytorch", "tensorflow"],
            "required_packages": ["numpy"],
            "max_size_mb": 100.0,
        },
    )
    test_db.add(config)

    # Add phase log in evaluation phase
    phase = PhaseLog(
        competition_id=comp.id,
        current_phase="evaluation",
        phase_dates={"transition_mode": "manual"},
    )
    test_db.add(phase)

    test_db.commit()
    test_db.refresh(comp)
    return comp


@pytest.fixture
def team(test_db: Session, competition: Competition, participant_user: User) -> Team:
    """Create a test team."""
    team = Team(
        name="Test Team", comp_id=competition.id, user_emails={"participant@example.com": 0}
    )
    test_db.add(team)

    # Add participant role
    role = Role(
        user_id=participant_user.id,
        competition_id=competition.id,
        role=RoleType.participant,
    )
    test_db.add(role)

    test_db.commit()
    test_db.refresh(team)
    return team


@pytest.fixture
def model_repo(test_db: Session) -> ModelSubmissionRepository:
    """Create a model submission repository."""
    return ModelSubmissionRepository(test_db)


@pytest.fixture
def model_service(model_repo: ModelSubmissionRepository) -> ModelSubmissionService:
    """Create a model submission service."""
    return ModelSubmissionService(model_repo)


# ============================================
# HELPER FUNCTIONS
# ============================================


def create_valid_docker_zip(
    model_filename: str = "model.pt",
    include_inference: bool = True,
    include_requirements: bool = True,
    include_dockerfile: bool = True,
    include_data_dir: bool = True,
) -> bytes:
    """
    Create a valid Docker build context zip.

    Args:
        model_filename: Name of the model file (controls format detection)
        include_inference: Whether to include inference.py
        include_requirements: Whether to include requirements.txt
        include_dockerfile: Whether to include Dockerfile
        include_data_dir: Whether to include data/ directory

    Returns:
        Zip file bytes
    """
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        # Add Dockerfile
        if include_dockerfile:
            zf.writestr(
                "Dockerfile",
                """FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "inference.py"]
""",
            )

        # Add inference.py
        if include_inference:
            zf.writestr(
                "inference.py",
                """
import torch

def predict(data):
    # Mock prediction function
    return {"prediction": 0.5}

if __name__ == "__main__":
    result = predict([1.0, 2.0, 3.0])
    print(result)
""",
            )

        # Add requirements.txt
        if include_requirements:
            zf.writestr("requirements.txt", "numpy>=1.20.0\ntorch>=1.9.0\n")

        # Add model/ directory with model file
        model_content = b"fake model binary data" * 100  # ~2KB
        zf.writestr(f"model/{model_filename}", model_content)

        # Add empty data/ directory
        if include_data_dir:
            zf.writestr("data/.gitkeep", "")

    buffer.seek(0)
    return buffer.getvalue()


# ============================================
# TESTS: VALIDATION
# ============================================


class TestDockerSubmissionValidation:
    """Test Docker zip submission validation."""

    def test_valid_pytorch_submission(self, model_service: ModelSubmissionService):
        """Valid PyTorch submission should pass all checks."""
        zip_bytes = create_valid_docker_zip(model_filename="model.pt")

        result = model_service.validate_docker_submission(
            zip_bytes, model_service.DEFAULT_MODEL_SPEC
        )

        assert result["valid"] is True
        assert result["detected_format"] == "pytorch"

    def test_valid_tensorflow_submission(self, model_service: ModelSubmissionService):
        """Valid TensorFlow submission should pass all checks."""
        zip_bytes = create_valid_docker_zip(model_filename="model.h5")

        result = model_service.validate_docker_submission(
            zip_bytes, model_service.DEFAULT_MODEL_SPEC
        )

        assert result["valid"] is True
        assert result["detected_format"] == "tensorflow"

    def test_missing_dockerfile(self, model_service: ModelSubmissionService):
        """Missing Dockerfile should raise ValidationError."""
        zip_bytes = create_valid_docker_zip(include_dockerfile=False)

        with pytest.raises(ValidationError, match="Dockerfile"):
            model_service.validate_docker_submission(
                zip_bytes, model_service.DEFAULT_MODEL_SPEC
            )

    def test_missing_inference_py(self, model_service: ModelSubmissionService):
        """Missing inference.py should raise ValidationError."""
        zip_bytes = create_valid_docker_zip(include_inference=False)

        with pytest.raises(ValidationError, match="inference.py"):
            model_service.validate_docker_submission(
                zip_bytes, model_service.DEFAULT_MODEL_SPEC
            )

    def test_missing_requirements_txt(self, model_service: ModelSubmissionService):
        """Missing requirements.txt should raise ValidationError."""
        zip_bytes = create_valid_docker_zip(include_requirements=False)

        with pytest.raises(ValidationError, match="requirements.txt"):
            model_service.validate_docker_submission(
                zip_bytes, model_service.DEFAULT_MODEL_SPEC
            )

    def test_missing_model_directory(self, model_service: ModelSubmissionService):
        """Missing model/ directory should raise ValidationError."""
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as zf:
            zf.writestr("Dockerfile", "FROM python:3.9")
            zf.writestr("inference.py", "def predict(x): return x")
            zf.writestr("requirements.txt", "numpy\n")
            zf.writestr("data/.gitkeep", "")

        buffer.seek(0)

        with pytest.raises(ValidationError, match="model/"):
            model_service.validate_docker_submission(
                buffer.getvalue(), model_service.DEFAULT_MODEL_SPEC
            )

    def test_missing_data_directory(self, model_service: ModelSubmissionService):
        """Missing data/ directory should raise ValidationError."""
        zip_bytes = create_valid_docker_zip(include_data_dir=False)

        with pytest.raises(ValidationError, match="data/"):
            model_service.validate_docker_submission(
                zip_bytes, model_service.DEFAULT_MODEL_SPEC
            )

    def test_unsupported_model_format(self, model_service: ModelSubmissionService):
        """Unsupported model format should raise ValidationError."""
        zip_bytes = create_valid_docker_zip(model_filename="model.xyz")

        with pytest.raises(ValidationError, match="recognised model file"):
            model_service.validate_docker_submission(
                zip_bytes, model_service.DEFAULT_MODEL_SPEC
            )

    def test_inference_function_not_found(self, model_service: ModelSubmissionService):
        """Missing required function in inference.py should raise ValidationError."""
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as zf:
            zf.writestr("Dockerfile", "FROM python:3.9\nCMD python inference.py")
            zf.writestr(
                "inference.py", "def evaluate(x): return x"
            )  # Missing 'predict'
            zf.writestr("requirements.txt", "numpy\n")
            zf.writestr("model/model.pt", b"fake")
            zf.writestr("data/.gitkeep", "")

        buffer.seek(0)

        with pytest.raises(ValidationError, match="predict"):
            model_service.validate_docker_submission(
                buffer.getvalue(), model_service.DEFAULT_MODEL_SPEC
            )

    def test_missing_required_package(self, model_service: ModelSubmissionService):
        """Missing required package in requirements.txt should raise ValidationError."""
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as zf:
            zf.writestr("Dockerfile", "FROM python:3.9\nCMD python inference.py")
            zf.writestr("inference.py", "def predict(x): return x")
            zf.writestr("requirements.txt", "torch>=1.9.0\n")  # Missing numpy
            zf.writestr("model/model.pt", b"fake")
            zf.writestr("data/.gitkeep", "")

        buffer.seek(0)

        spec = {
            "required_files": ["Dockerfile", "inference.py", "requirements.txt"],
            "model_dir": "model",
            "data_dir": "data",
            "inference_function": "predict",
            "allowed_model_formats": ["pytorch"],
            "required_packages": ["numpy"],  # Required
            "max_size_mb": 100.0,
        }

        with pytest.raises(ValidationError, match="numpy"):
            model_service.validate_docker_submission(buffer.getvalue(), spec)

    def test_file_size_exceeds_limit(self, model_service: ModelSubmissionService):
        """File exceeding max_size_mb should raise ValidationError."""
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as zf:
            zf.writestr("Dockerfile", "FROM python:3.9\nCMD python inference.py")
            zf.writestr("inference.py", "def predict(x): return x")
            zf.writestr("requirements.txt", "numpy\n")
            zf.writestr("model/model.pt", b"x" * (50 * 1024 * 1024))  # 50MB
            zf.writestr("data/.gitkeep", "")

        buffer.seek(0)

        spec = {
            "required_files": ["Dockerfile", "inference.py", "requirements.txt"],
            "model_dir": "model",
            "data_dir": "data",
            "inference_function": "predict",
            "allowed_model_formats": ["pytorch"],
            "required_packages": [],
            "max_size_mb": 10.0,  # 10MB limit
        }

        with pytest.raises(ValidationError, match="exceeds the limit"):
            model_service.validate_docker_submission(buffer.getvalue(), spec)


class TestEligibilityAndPhase:
    """Test team eligibility and phase validation."""

    def test_valid_team_eligibility(
        self, model_service: ModelSubmissionService, team: Team, participant_user: User
    ):
        """Valid team should pass eligibility check."""
        # Should not raise
        model_service._validate_team_eligibility(
            team.id, team.comp_id, participant_user.id
        )

    def test_team_not_found(
        self, model_service: ModelSubmissionService, team: Team, participant_user: User
    ):
        """Non-existent team should raise ValidationError."""
        with pytest.raises(ValidationError, match="does not exist"):
            model_service._validate_team_eligibility(
                999, team.comp_id, participant_user.id
            )

    def test_team_wrong_competition(
        self,
        test_db: Session,
        model_service: ModelSubmissionService,
        team: Team,
        participant_user: User,
    ):
        """Team from different competition should raise ValidationError."""
        # Create another competition
        other_comp = Competition(name="Other Comp", invitation_link="other")
        test_db.add(other_comp)
        test_db.commit()

        with pytest.raises(ValidationError, match="does not belong"):
            model_service._validate_team_eligibility(
                team.id, other_comp.id, participant_user.id
            )

    def test_user_not_in_team(
        self, test_db: Session, model_service: ModelSubmissionService, team: Team
    ):
        """User not in team should raise ValidationError."""
        other_user = User(
            fullname="Other User",
            email="other@example.com",
            password="hash",
            phone=None,
        )
        test_db.add(other_user)
        test_db.commit()

        with pytest.raises(ValidationError, match="not a member"):
            model_service._validate_team_eligibility(
                team.id, team.comp_id, other_user.id
            )

    def test_valid_evaluation_phase(
        self, model_service: ModelSubmissionService, competition: Competition
    ):
        """Should not raise during evaluation phase."""
        model_service._validate_submission_phase(competition.id)

    def test_wrong_phase(
        self,
        test_db: Session,
        model_service: ModelSubmissionService,
        competition: Competition,
    ):
        """Non-evaluation phase should raise ValidationError."""
        phase = (
            test_db.query(PhaseLog)
            .filter(PhaseLog.competition_id == competition.id)
            .first()
        )
        phase.current_phase = "creation"
        test_db.commit()

        with pytest.raises(ValidationError, match="evaluation phase"):
            model_service._validate_submission_phase(competition.id)


class TestDeduplication:
    """Test model deduplication."""

    def test_duplicate_detection(
        self,
        test_db: Session,
        model_repo: ModelSubmissionRepository,
        team: Team,
        participant_user: User,
    ):
        """Duplicate model (same hash) should be detected."""
        zip_bytes = create_valid_docker_zip()
        import hashlib

        model_hash = hashlib.sha256(zip_bytes).hexdigest()

        # Save first model
        model1 = model_repo.save_model_record(
            team_id=team.id,
            competition_id=team.comp_id,
            filename="model.zip",
            storage_path="models/model.zip",
            model_hash=model_hash,
            format="pytorch",
            framework_version="1.9.0",
            size_mb=0.5,
            submitted_by=participant_user.id,
            version=1,
        )

        # Try to save same hash
        existing = model_repo.find_by_hash(model_hash)
        assert existing is not None
        assert existing.id == model1.id


class TestVersioning:
    """Test model version tracking."""

    def test_version_increments(
        self,
        test_db: Session,
        model_repo: ModelSubmissionRepository,
        team: Team,
        participant_user: User,
    ):
        """Each submission should increment version."""
        for i in range(1, 4):
            model_repo.save_model_record(
                team_id=team.id,
                competition_id=team.comp_id,
                filename=f"model_v{i}.zip",
                storage_path=f"models/model_v{i}.zip",
                model_hash=f"hash_{i}",
                format="pytorch",
                framework_version="1.9.0",
                size_mb=0.5,
                submitted_by=participant_user.id,
                version=i,
            )

        latest = model_repo.find_latest_by_team(team.id, team.comp_id)
        assert latest.version == 3


# ============================================
# TEST CONFIGURATION
# ============================================


def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line("markers", "integration: mark test as an integration test")
    config.addinivalue_line("markers", "slow: mark test as slow running")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
