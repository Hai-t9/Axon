from uuid import UUID

from app.core.exceptions import NotFoundError, ValidationError
from app.models import Label

from .repository import DataValidationRepository


class DataValidationService:
    def __init__(self, repository: DataValidationRepository):
        self.repository = repository

    def get_queue(self, comp_id: UUID, user_id: UUID) -> dict:
        team_id = self.repository.get_team_id_for_user(comp_id, user_id)
        if not team_id:
            raise NotFoundError("You are not assigned to any team in this competition")
        images = self.repository.get_images_for_validation(team_id)
        return {"images": images, "total": len(images)}

    def validate(self, image_id: int, user_id: UUID) -> dict:
        label = (
            self.repository.db.query(Label)
            .filter(Label.image_id == image_id)
            .first()
        )
        if not label:
            raise NotFoundError("Label not found for this image")
        if label.validated:
            raise ValidationError("Label already validated")
        self.repository.validate_label(label.id)
        return {"success": True, "message": "Label validated"}

    def skip(self, image_id: int, user_id: UUID) -> dict:
        return {"success": True, "message": "Image skipped"}

    def correct(self, image_id: int, new_label: str, user_id: UUID) -> dict:
        label = (
            self.repository.db.query(Label)
            .filter(Label.image_id == image_id)
            .first()
        )
        if not label:
            raise NotFoundError("Label not found for this image")
        self.repository.correct_label(label.id, new_label)
        return {"success": True, "message": "Label corrected"}

    def get_progress(self, comp_id: UUID, user_id: UUID) -> dict:
        team_id = self.repository.get_team_id_for_user(comp_id, user_id)
        if not team_id:
            raise NotFoundError("You are not assigned to any team in this competition")
        total = self.repository.count_total(team_id)
        validated = self.repository.count_validated(team_id)
        pending = total - validated
        percentage = (validated / total * 100) if total > 0 else 0
        return {
            "total_images": total,
            "validated_images": validated,
            "pending_images": pending,
            "progress_percentage": round(percentage, 1),
        }
