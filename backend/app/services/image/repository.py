from sqlalchemy.orm import Session
from app.models.image import Image, ImageMetadata

class ImageRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, image_data: dict, metadata_data: dict):
        db_image = Image(**image_data)
        self.db.add(db_image)
        self.db.commit()
        self.db.refresh(db_image)

        db_metadata = ImageMetadata(**metadata_data, image_id=db_image.id)
        self.db.add(db_metadata)
        self.db.commit()
        return db_image

    def find_by_id(self, image_id: int):
        return self.db.query(Image).filter(Image.id == image_id).first()

    def find_by_hash(self, image_hash: str):
        return self.db.query(Image).filter(Image.image_hash == image_hash).first()

    def update_status(self, image_id: int, status: str):
        db_image = self.find_by_id(image_id)
        if db_image:
            db_image.status = status
            self.db.commit()
            self.db.refresh(db_image)
        return db_image

    def find_by_team(self, team_id: int, status: str = None, skip: int = 0, limit: int = 100):
        query = self.db.query(Image).filter(Image.team_id == team_id)
        if status:
            query = query.filter(Image.status == status)
        total = query.count()
        images = query.offset(skip).limit(limit).all()
        return images, total

    def find_by_competition(self, comp_id: int, status: str = None):
        # MOCK comp logic for now
        query = self.db.query(Image)
        if status:
            query = query.filter(Image.status == status)
        total = query.count()
        return query.all(), total

    def delete(self, image_id: int):
        img = self.find_by_id(image_id)
        if img:
            self.db.query(ImageMetadata).filter(ImageMetadata.image_id == image_id).delete()
            self.db.delete(img)
            self.db.commit()
            return True
        return False
