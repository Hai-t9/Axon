from sqlalchemy.orm import Session
from uuid import UUID

from app.models import Image, Label, Team


class LabelRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_image_by_id(self, image_id: int) -> Image | None:
        return self.db.query(Image).filter(Image.id == image_id).first()

    def get_competition_id_for_image(self, image_id: int) -> UUID | None:
        return (
            self.db.query(Team.comp_id)
            .join(Image, Image.team_id == Team.id)
            .filter(Image.id == image_id)
            .scalar()
        )

    def find_by_image_id(self, image_id: int) -> Label | None:
        return self.db.query(Label).filter(Label.image_id == image_id).first()

    def insert_label(self, image_id: int, label: str) -> Label:
        entry = Label(image_id=image_id, label=label, validated=False)
        self.db.add(entry)
        self.db.commit()
        self.db.refresh(entry)
        return entry

    def modify_label(self, image_id: int, label: str) -> Label | None:
        entry = self.find_by_image_id(image_id)
        if not entry:
            return None
        entry.label = label
        self.db.commit()
        self.db.refresh(entry)
        return entry

    def set_label_validated(self, image_id: int) -> Label | None:
        entry = self.find_by_image_id(image_id)
        if not entry:
            return None
        entry.validated = True
        self.db.commit()
        self.db.refresh(entry)
        return entry
