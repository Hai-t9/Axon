from uuid import uuid4

from sqlalchemy import JSON, Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base
from app.models.model_enums import (
    evaluation_protocol_enum,
    evaluation_status_enum,
    task_status_enum,
)


class Evaluation(Base):
    __tablename__ = "evaluation"

    id = Column(Integer, primary_key=True)
    model_id = Column(
        PostgresUUID(as_uuid=True), ForeignKey("model.id"), unique=True, nullable=False
    )
    score = Column(Float, nullable=False)
    evaluated_at = Column(DateTime, server_default=func.now())

    model = relationship("Model", back_populates="evaluation")


class EvaluationJob(Base):
    __tablename__ = "evaluation_job"

    id = Column(PostgresUUID(as_uuid=True), primary_key=True, default=uuid4)
    model_id = Column(
        PostgresUUID(as_uuid=True), ForeignKey("model.id"), unique=True, nullable=False
    )
    competition_id = Column(
        PostgresUUID(as_uuid=True), ForeignKey("competition.id"), nullable=False
    )
    protocol = Column(evaluation_protocol_enum, nullable=False)
    status = Column(evaluation_status_enum, default="scheduled")
    total_folds = Column(Integer, nullable=False)
    completed_folds = Column(Integer, default=0)
    retry_count = Column(Integer, default=0)
    max_retries = Column(Integer, default=3)
    created_at = Column(DateTime, server_default=func.now())
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)

    model = relationship("Model", back_populates="evaluation_job")
    tasks = relationship("EvaluationTask", back_populates="job", cascade="all, delete-orphan")
    results = relationship("EvaluationResult", back_populates="job", cascade="all, delete-orphan")


class EvaluationTask(Base):
    __tablename__ = "evaluation_task"

    id = Column(PostgresUUID(as_uuid=True), primary_key=True, default=uuid4)
    evaluation_id = Column(
        PostgresUUID(as_uuid=True), ForeignKey("evaluation_job.id"), nullable=False
    )
    task_number = Column(Integer, nullable=False)
    status = Column(task_status_enum, default="pending")
    worker_id = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    error_message = Column(String, nullable=True)

    job = relationship("EvaluationJob", back_populates="tasks")
    result = relationship("EvaluationResult", back_populates="task", uselist=False)


class EvaluationResult(Base):
    __tablename__ = "evaluation_result"

    id = Column(PostgresUUID(as_uuid=True), primary_key=True, default=uuid4)
    evaluation_id = Column(
        PostgresUUID(as_uuid=True), ForeignKey("evaluation_job.id"), nullable=False
    )
    task_id = Column(
        PostgresUUID(as_uuid=True), ForeignKey("evaluation_task.id"), unique=True, nullable=False
    )
    fold_number = Column(Integer, nullable=False)
    accuracy = Column(Float, nullable=False)
    precision = Column(Float, nullable=False)
    recall = Column(Float, nullable=False)
    f1_score = Column(Float, nullable=False)
    confusion_matrix = Column(JSON, nullable=True)
    execution_time_seconds = Column(Float, nullable=True)
    computed_at = Column(DateTime, server_default=func.now())

    job = relationship("EvaluationJob", back_populates="results")
    task = relationship("EvaluationTask", back_populates="result")
