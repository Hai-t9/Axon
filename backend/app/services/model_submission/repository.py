from typing import List, Optional, Tuple
from uuid import UUID

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import Model, ModelMetadata
from app.models.model_competition import Config
from app.models.model_model import ModelFormat, ModelStatus
from app.models.model_phase import PhaseLog
from app.models.model_team import Team


class ModelSubmissionRepository:
    """Repository for model submission database operations"""

    def __init__(self, db: Session):
        self.db = db

    def save_model_record(
        self,
        team_id: UUID,
        competition_id: UUID,
        filename: str,
        storage_path: str,
        model_hash: str,
        format: str,
        framework_version: str,
        size_mb: float,
        submitted_by: UUID,
        version: int,
    ) -> Model:
        """Save a new model submission record to the database"""
        model = Model(
            team_id=team_id,
            competition_id=competition_id,
            filename=filename,
            storage_path=storage_path,
            model_hash=model_hash,
            format=ModelFormat(format),  # convert string → enum member
            framework_version=framework_version,
            size_mb=size_mb,
            submitted_by=submitted_by,
            version=version,
            status=ModelStatus.RECEIVED,
        )
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return model

    def save_model_metadata(self, model_id: UUID, metadata_data: dict) -> ModelMetadata:
        """Save model metadata for a submitted model"""
        metadata = ModelMetadata(
            model_id=model_id,
            model_name=metadata_data.get("model_name"),
            description=metadata_data.get("description"),
            framework=metadata_data.get("framework"),
            framework_version=metadata_data.get("framework_version"),
            python_version=metadata_data.get("python_version"),
            dependencies=metadata_data.get("dependencies"),
            input_shape=metadata_data.get("input_shape"),
            output_shape=metadata_data.get("output_shape"),
            training_dataset=metadata_data.get("training_dataset"),
            performance_metrics=metadata_data.get("performance_metrics"),
        )
        self.db.add(metadata)
        self.db.commit()
        self.db.refresh(metadata)
        return metadata

    def find_by_id(self, model_id: UUID) -> Optional[Model]:
        """Find a model by ID"""
        return self.db.query(Model).filter(Model.id == model_id).first()

    def find_by_hash(self, model_hash: str) -> Optional[Model]:
        """Find a model by hash (for deduplication)"""
        return self.db.query(Model).filter(Model.model_hash == model_hash).first()

    def find_by_team(
        self, team_id: UUID, comp_id: UUID, skip: int = 0, limit: int = 100
    ) -> Tuple[List[Model], int]:
        """Find all models submitted by a team in a competition"""
        query = self.db.query(Model).filter(
            Model.team_id == team_id, Model.competition_id == comp_id
        )
        total = query.count()
        models = query.offset(skip).limit(limit).all()
        return models, total

    def find_by_competition(
        self, comp_id: UUID, skip: int = 0, limit: int = 100
    ) -> Tuple[List[Model], int]:
        """Find all models in a competition"""
        query = self.db.query(Model).filter(Model.competition_id == comp_id)
        total = query.count()
        models = query.offset(skip).limit(limit).all()
        return models, total

    def find_latest_by_team(self, team_id: UUID, comp_id: UUID) -> Optional[Model]:
        """Find the latest model version submitted by a team"""
        return (
            self.db.query(Model)
            .filter(Model.team_id == team_id, Model.competition_id == comp_id)
            .order_by(Model.version.desc())
            .first()
        )

    def count_by_team(self, team_id: UUID, comp_id: UUID) -> int:
        """Count models submitted by a team"""
        return (
            self.db.query(func.count(Model.id))
            .filter(Model.team_id == team_id, Model.competition_id == comp_id)
            .scalar()
        )

    def update_status(self, model_id: UUID, status: ModelStatus) -> Model:
        """Update the status of a model"""
        model = self.find_by_id(model_id)
        if model:
            model.status = status  # type: ignore[assignment]
            self.db.commit()
            self.db.refresh(model)
        return model  # type: ignore[return-value]

    def update_scheduled_at(self, model_id: UUID) -> Model:
        """Update the scheduled_at timestamp"""
        from datetime import datetime

        model = self.find_by_id(model_id)
        if model:
            model.scheduled_at = datetime.utcnow()  # type: ignore[assignment]
            self.db.commit()
            self.db.refresh(model)
        return model  # type: ignore[return-value]

    def delete_model(self, model_id: UUID) -> bool:
        """Delete a model and its metadata"""
        model = self.find_by_id(model_id)
        if model:
            # Delete metadata first (foreign key constraint)
            self.db.query(ModelMetadata).filter(
                ModelMetadata.model_id == model_id
            ).delete()
            self.db.delete(model)
            self.db.commit()
            return True
        return False

    def get_model_with_metadata(self, model_id: UUID) -> Optional[Model]:
        """Get a model with its metadata loaded"""
        return (
            self.db.query(Model)
            .filter(Model.id == model_id)
            .outerjoin(ModelMetadata)
            .first()
        )

    def get_team_submission_history(
        self, team_id: UUID, comp_id: UUID
    ) -> Tuple[List[Model], dict]:
        """Get all model submissions from a team with version stats"""
        models, total = self.find_by_team(team_id, comp_id, skip=0, limit=1000)

        # Count submissions grouped by status
        status_counts = (
            self.db.query(Model.status, func.count(Model.id))
            .filter(Model.team_id == team_id, Model.competition_id == comp_id)
            .group_by(Model.status)
            .all()
        )
        versions = {
            str(status).split(".")[-1]: count for status, count in status_counts
        }

        return models, versions

    def find_competition_config(self, comp_id: UUID) -> Optional[Config]:
        """Fetch the competition config (contains model_spec set by the organizer)"""
        return self.db.query(Config).filter(Config.competition_id == comp_id).first()

    def find_team(self, team_id: UUID) -> Optional[Team]:
        """Fetch a team by ID (used for eligibility checks)"""
        return self.db.query(Team).filter(Team.id == team_id).first()

    def find_phase(self, comp_id: UUID) -> Optional[PhaseLog]:
        """Fetch the current phase log for a competition"""
        return (
            self.db.query(PhaseLog).filter(PhaseLog.competition_id == comp_id).first()
        )

    def find_all_by_team(
        self, team_id: UUID, skip: int = 0, limit: int = 100
    ) -> Tuple[List[Model], int]:
        """Find all models submitted by a team across all competitions"""
        query = self.db.query(Model).filter(Model.team_id == team_id)
        total = query.count()
        models = (
            query.order_by(Model.submitted_at.desc()).offset(skip).limit(limit).all()
        )
        return models, total
