from datetime import date
from typing import Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel


class ModelSpec(BaseModel):
    """
    Organizer-defined specification for Docker-based model submissions.
    Set this in competition config before the evaluation phase opens.
    """

    required_files: List[str] = [
        "Dockerfile",
        "inference.py",
        "requirements.txt",
    ]  # utils.py may be added
    model_dir: str = "model"
    data_dir: str = "data"
    inference_function: str = "predict"
    allowed_model_formats: List[str] = [
        "pytorch",
        "tensorflow",
        "sklearn",
        "keras",
        "onnx",
    ]
    required_packages: List[str] = []
    max_size_mb: float = 500.0
    python_version_min: Optional[str] = None


class CompetitionConfigBase(BaseModel):
    labels: Optional[dict] = None
    data_ex: Optional[str] = None
    scoring_ex: Optional[str] = None
    overview: Optional[str] = None
    terms_conditions: Optional[str] = None
    data_md: Optional[str] = None
    data_format: Optional[str] = None
    evaluation: Optional[str] = None
    duplicate_threshhold: Optional[float] = None
    max_validations: Optional[int] = None
    model_spec: Optional[ModelSpec] = None


class CompetitionConfigResponse(CompetitionConfigBase):
    id: UUID
    competition_id: UUID

    class Config:
        from_attributes = True


class CompetitionCreate(BaseModel):
    name: str
    description: Optional[str] = None
    launch_date: Optional[date] = None
    config: Optional[CompetitionConfigBase] = None
    phase_deadlines: Optional[Dict[str, str]] = None


class CompetitionUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    launch_date: Optional[date] = None
    invitation_link: Optional[str] = None


class CompetitionResponse(BaseModel):
    id: UUID
    name: str
    description: Optional[str] = None
    launch_date: Optional[date] = None
    invitation_link: Optional[str] = None
    config: Optional[CompetitionConfigResponse] = None

    class Config:
        from_attributes = True


class CompetitionListResponse(BaseModel):
    items: List[CompetitionResponse]
    total: int
    page: int
    limit: int
