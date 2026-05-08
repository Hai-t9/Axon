from enum import Enum as PyEnum
from uuid import uuid4

from sqlalchemy import (
    JSON,
    Column,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
)
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class ModelFormat(PyEnum):
    """Supported model formats"""

    TENSORFLOW = "tensorflow"
    PYTORCH = "pytorch"
    SKLEARN = "sklearn"
    KERAS = "keras"
    ONNX = "onnx"


class ModelStatus(PyEnum):
    """Model submission and evaluation status"""

    RECEIVED = "received"
    VALIDATED = "validated"
    SCHEDULED = "scheduled"
    QUEUED = "queued"
    EVALUATING = "evaluating"
    COMPLETED = "completed"


class Model(Base):
    __tablename__ = "model"

    id = Column(PostgresUUID(as_uuid=True), primary_key=True, default=uuid4)
    team_id = Column(PostgresUUID(as_uuid=True), ForeignKey("team.id"), nullable=False)
    competition_id = Column(
        PostgresUUID(as_uuid=True), ForeignKey("competition.id"), nullable=False
    )
    submitted_by = Column(
        PostgresUUID(as_uuid=True), ForeignKey("user.id"), nullable=False
    )

    filename = Column(String, nullable=False)
    storage_path = Column(String, nullable=False)
    model_hash = Column(String, nullable=False)

    format = Column(Enum(ModelFormat), nullable=False)
    framework_version = Column(String, nullable=False)
    size_mb = Column(Float, nullable=False)
    status = Column(Enum(ModelStatus), nullable=False, default=ModelStatus.RECEIVED)
    version = Column(Integer, nullable=False)

    submitted_at = Column(DateTime, nullable=False, server_default=func.now())
    scheduled_at = Column(DateTime, nullable=True)

    team = relationship("Team", back_populates="models")
    competition = relationship("Competition", back_populates="models")
    submitted_by_user = relationship("User", back_populates="submitted_models")
    model_metadata = relationship(
        "ModelMetadata",
        uselist=False,
        cascade="all, delete-orphan",
    )
    evaluation = relationship(
        "Evaluation",
        back_populates="model",
        uselist=False,
        cascade="all, delete-orphan",
    )
    evaluation_job = relationship(
        "EvaluationJob",
        back_populates="model",
        uselist=False,
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        Index("idx_model_submitted_by", "submitted_by"),
        Index("idx_model_status", "status"),
        Index("idx_model_hash", "model_hash"),
    )


class ModelMetadata(Base):
    """Stores additional metadata for submitted models"""

    __tablename__ = "model_metadata"

    id = Column(Integer, primary_key=True)
    model_id = Column(
        PostgresUUID(as_uuid=True), ForeignKey("model.id"), unique=True, nullable=False
    )

    model_name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    framework = Column(String, nullable=False)
    framework_version = Column(String, nullable=True)
    python_version = Column(String, nullable=False)
    dependencies = Column(JSON, nullable=True)  # List of package names
    input_shape = Column(String, nullable=True)
    output_shape = Column(String, nullable=True)
    training_dataset = Column(String, nullable=True)
    performance_metrics = Column(JSON, nullable=True)  # Optional performance metrics

    created_at = Column(DateTime, nullable=False, server_default=func.now())
