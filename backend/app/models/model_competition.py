from uuid import uuid4

from sqlalchemy import Column, Date, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import relationship

from app.core.database import Base


class Competition(Base):
    __tablename__ = "competition"

    id = Column(PostgresUUID(as_uuid=True), primary_key=True, default=uuid4)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    launch_date = Column(Date, nullable=True)
    invitation_link = Column(String, unique=True, nullable=True)

    roles = relationship(
        "Role", back_populates="competition", cascade="all, delete-orphan"
    )
    config = relationship(
        "Config",
        back_populates="competition",
        uselist=False,
        cascade="all, delete-orphan",
        lazy="noload",
    )
    teams = relationship(
        "Team", back_populates="competition", cascade="all, delete-orphan"
    )
    phase_logs = relationship(
        "PhaseLog", back_populates="competition", cascade="all, delete-orphan"
    )
    models = relationship(
        "Model", back_populates="competition", cascade="all, delete-orphan"
    )


class Config(Base):
    __tablename__ = "config"

    id = Column(Integer, primary_key=True)
    competition_id = Column(
        PostgresUUID(as_uuid=True),
        ForeignKey("competition.id"),
        unique=True,
        nullable=False,
    )
    labels = Column(JSON, nullable=True)  # JSONB in database
    data_ex = Column(String, nullable=True)
    scoring_ex = Column(String, nullable=True)
    overview = Column(String, nullable=True)
    terms_conditions = Column(String, nullable=True)
    data_md = Column(String, nullable=True)
    data_format = Column(String, nullable=True)
    evaluation = Column(String, nullable=True)
    duplicate_threshhold = Column(Float, nullable=True)
    max_validations = Column("maxValidations", Integer, nullable=True)
    model_spec = Column(JSON, nullable=True)  # JSONB in database
    # model_spec stores the organizer's Docker submission requirements, e.g.:
    # {
    #   "required_files": ["Dockerfile", "inference.py", "requirements.txt"],
    #   "model_dir": "model",
    #   "data_dir": "data",
    #   "inference_function": "predict",
    #   "allowed_model_formats": ["pytorch", "tensorflow", "sklearn", "keras", "onnx"],
    #   "required_packages": ["numpy"],
    #   "max_size_mb": 500,
    #   "python_version_min": "3.9"
    # }

    competition = relationship(
        "Competition", back_populates="config", foreign_keys=[competition_id]
    )
