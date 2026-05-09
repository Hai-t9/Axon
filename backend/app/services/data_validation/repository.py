from uuid import UUID

from sqlalchemy.orm import Session

from app.models import Image, Label, Team


class DataValidationRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_team_id_for_user(self, comp_id: UUID, user_id: UUID) -> UUID | None:
        from app.models import User

        teams = self.db.query(Team).filter(Team.comp_id == comp_id).all()
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user or not user.email:
            return None
        for team in teams:
            emails = team.user_emails or {}
            if user.email.strip().lower() in {
                k.strip().lower() for k in emails.keys()
            }:
                return team.id
        return None

    def get_images_for_validation(self, team_id: UUID) -> list[dict]:
        rows = (
            self.db.query(Image, Label)
            .join(Label, Label.image_id == Image.id)
            .filter(Image.team_id == team_id)
            .filter(Label.validated.is_(False))
            .all()
        )
        return [
            {
                "image_id": img.id,
                "filepath": img.filepath,
                "current_label": lb.label,
                "label_id": lb.id,
            }
            for img, lb in rows
        ]

    def validate_label(self, label_id: int) -> None:
        self.db.query(Label).filter(Label.id == label_id).update(
            {"validated": True}
        )
        self.db.commit()

    def correct_label(self, label_id: int, new_label: str) -> None:
        self.db.query(Label).filter(Label.id == label_id).update(
            {"label": new_label, "validated": True}
        )
        self.db.commit()

    def count_validated(self, team_id: UUID) -> int:
        return (
            self.db.query(Label)
            .join(Image, Label.image_id == Image.id)
            .filter(Image.team_id == team_id)
            .filter(Label.validated.is_(True))
            .count()
        )

    def count_total(self, team_id: UUID) -> int:
        return (
            self.db.query(Label)
            .join(Image, Label.image_id == Image.id)
            .filter(Image.team_id == team_id)
            .count()
        )
