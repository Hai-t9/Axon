from uuid import UUID

from sqlalchemy.orm import Session

from app.models.model_image import Image, ImageMetadata
from app.models.model_label import Label, LabelValidation
from app.models.model_team import Team
from app.models.model_user import User

# Helper: UUIDs masquerading as ints in the model
_ImageId = UUID


class ExportRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_team_images_with_labels(self, team_id: UUID) -> list[Image]:
        return (
            self.db.query(Image)
            .filter(Image.team_id == team_id)
            .order_by(Image.time.desc())
            .all()
        )

    def get_all_competition_images(self, comp_id: UUID) -> list[Image]:
        return (
            self.db.query(Image)
            .join(Team, Image.team_id == Team.id)
            .filter(Team.comp_id == comp_id)
            .order_by(Team.name, Image.time.desc())
            .all()
        )

    def get_labels_for_images(self, image_ids: list[_ImageId]) -> list[Label]:
        if not image_ids:
            return []
        return (
            self.db.query(Label)
            .filter(Label.image_id.in_(image_ids))
            .all()
        )

    def get_validations_for_labels(self, label_ids: list[int]) -> list[LabelValidation]:
        if not label_ids:
            return []
        return (
            self.db.query(LabelValidation)
            .filter(LabelValidation.label_id.in_(label_ids))
            .order_by(LabelValidation.validated_at)
            .all()
        )

    def get_metadata_for_images(self, image_ids: list[_ImageId]) -> list[ImageMetadata]:
        if not image_ids:
            return []
        return (
            self.db.query(ImageMetadata)
            .filter(ImageMetadata.image_id.in_(image_ids))
            .all()
        )

    def get_team_name(self, team_id: UUID) -> str | None:
        team = self.db.query(Team).filter(Team.id == team_id).first()
        return team.name if team else None

    def get_team_comp_id(self, team_id: UUID) -> UUID | None:
        team = self.db.query(Team).filter(Team.id == team_id).first()
        return team.comp_id if team else None

    def get_team_for_user(self, comp_id: UUID, user_id: UUID) -> Team | None:
        teams = self.db.query(Team).filter(Team.comp_id == comp_id).all()
        for team in teams:
            emails = team.user_emails or {}
            user = self.db.query(User).filter(User.id == user_id).first()
            if user and user.email and emails.get(user.email) == 1:
                return team
        return None

    def get_user_name(self, user_id: UUID) -> str | None:
        user = self.db.query(User).filter(User.id == user_id).first()
        return user.fullname if user else None
