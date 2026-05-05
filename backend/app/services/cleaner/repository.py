from sqlalchemy.orm import Session
from typing import List
from app.models.image import Image, ImageMetadata

class CleanerRepository:
    def __init__(self, db: Session):
        self.db = db

    def find_images_by_competition(self, comp_id: int) -> List[Image]:
        # Using simple query, theoretically join with Team
        return self.db.query(Image).all()

    def find_duplicates_by_hash(self, image_hash: str) -> List[Image]:
        return self.db.query(Image).filter(Image.image_hash == image_hash).all()

    def find_corrupted_images(self) -> List[Image]:
        return self.db.query(Image).filter(
            (Image.old_size_mb == 0.0) | (Image.image_hash == None)
        ).all()

    def find_unlabeled_images(self, comp_id: int) -> List[Image]:
        return self.db.query(Image).filter(Image.label == None).all()

    def bulk_update(self, images: List[Image]):
        for img in images:
            db_img = self.db.query(Image).filter(Image.id == img.id).first()
            if db_img:
                db_img.status = img.status
        self.db.commit()
        return len(images)

    def bulk_delete(self, images: List[Image]):
        count = 0
        for img in images:
            self.db.query(ImageMetadata).filter(ImageMetadata.image_id == img.id).delete()
            if self.db.query(Image).filter(Image.id == img.id).delete():
                count += 1
        self.db.commit()
        return count

