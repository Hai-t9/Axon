from typing import List, Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.model_image import Image, ImageMetadata
from app.models.model_label import Label
from app.models.model_team import Team


class CleanerRepository:
    def __init__(self, db: Session):
        self.db = db

    # ── Queries ──────────────────────────────────────────────

    def find_images_by_competition(self, comp_id: UUID) -> List[Image]:
        return (
            self.db.query(Image)
            .join(Team, Image.team_id == Team.id)
            .filter(Team.comp_id == comp_id)
            .all()
        )

    def find_duplicates_by_hash(self, image_hash: str) -> List[Image]:
        return self.db.query(Image).filter(Image.image_hash == image_hash).all()

    def find_corrupted_images(self) -> List[Image]:
        return self.db.query(Image).filter(
            (Image.old_size_mb == 0.0) | (Image.image_hash.is_(None))
        ).all()

    def find_unlabeled_images(self, comp_id: UUID) -> List[Image]:
        return (
            self.db.query(Image)
            .join(Team, Image.team_id == Team.id)
            .filter(Team.comp_id == comp_id, Image.label.is_(None))
            .all()
        )

    def find_images_by_team(self, team_id: UUID) -> List[Image]:
        return self.db.query(Image).filter(Image.team_id == team_id).all()

    def get_team_comp_id(self, team_id: UUID) -> Optional[UUID]:
        team = self.db.query(Team).filter(Team.id == team_id).first()
        return team.comp_id if team else None

    # ── Bulk operations ──────────────────────────────────────

    def bulk_update(self, images: List[Image]):
        for img in images:
            db_img = self.db.query(Image).filter(Image.id == img.id).first()
            if db_img:
                db_img.status = img.status
        self.db.commit()

    def bulk_delete(self, images: List[Image]):
        count = 0
        for img in images:
            self.db.query(ImageMetadata).filter(ImageMetadata.image_id == img.id).delete()
            self.db.query(Label).filter(Label.image_id == img.id).delete()
            if self.db.query(Image).filter(Image.id == img.id).delete():
                count += 1
        self.db.commit()
        return count

    # ── Cleaner module helpers ───────────────────────────────

    def mark_duplicate(
        self,
        image_id: int,
        duplicate_of_id: int,
        reason: str,
    ):
        self.db.query(Image).filter(Image.id == image_id).update(
            {
                "is_duplicate": True,
                "duplicate_of_id": duplicate_of_id,
                "duplicate_reason": reason,
            }
        )

    def clear_duplicate_flags(self, comp_id: UUID):
        image_ids = [
            r[0]
            for r in (
                self.db.query(Image.id)
                .join(Team, Image.team_id == Team.id)
                .filter(Team.comp_id == comp_id, Image.is_duplicate.is_(True))
                .all()
            )
        ]
        if image_ids:
            self.db.query(Image).filter(Image.id.in_(image_ids)).update(
                {
                    "is_duplicate": False,
                    "duplicate_of_id": None,
                    "duplicate_reason": None,
                },
                synchronize_session=False,
            )

    def mark_corrupted(self, image_id: int, error_message: str):
        self.db.query(Image).filter(Image.id == image_id).update(
            {
                "corrupted": True,
                "corrupted_error": error_message,
            }
        )

    def mark_not_corrupted(self, image_id: int):
        self.db.query(Image).filter(Image.id == image_id).update(
            {
                "corrupted": False,
                "corrupted_error": None,
            }
        )

    def update_label(self, image_id: int, new_label: str):
        self.db.query(Image).filter(Image.id == image_id).update({"label": new_label})

    def update_image_filepath(self, image_id: int, new_filepath: str):
        self.db.query(Image).filter(Image.id == image_id).update(
            {"filepath": new_filepath}
        )

    def update_metadata_after_resize(
        self,
        image_id: int,
        new_width: float,
        new_height: float,
        new_size_mb: float,
        resizing_method: str,
        format_change: str,
        original_resolution: str,
        new_resolution: str,
    ):
        meta = (
            self.db.query(ImageMetadata)
            .filter(ImageMetadata.image_id == image_id)
            .first()
        )
        if meta:
            meta.new_width = new_width
            meta.new_height = new_height
            meta.new_size_mb = new_size_mb
            meta.resizing_method = resizing_method
            meta.format_change = format_change
            meta.original_resolution = original_resolution
            meta.new_resolution = new_resolution
        else:
            self.db.add(
                ImageMetadata(
                    image_id=image_id,
                    new_width=new_width,
                    new_height=new_height,
                    new_size_mb=new_size_mb,
                    resizing_method=resizing_method,
                    format_change=format_change,
                    original_resolution=original_resolution,
                    new_resolution=new_resolution,
                )
            )

    def commit(self):
        self.db.commit()
