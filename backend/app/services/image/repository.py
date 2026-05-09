from sqlalchemy.orm import Session
from uuid import UUID
from app.models.model_image import Image, ImageMetadata
from app.models.model_label import Label

class ImageRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_team_info(self, team_id: UUID) -> tuple[UUID, str, str] | None:
        from app.models.model_team import Team
        team = self.db.query(Team).filter(Team.id == team_id).first()
        if not team:
            return None
        return (team.comp_id, team.competition.name, team.name)

    def get_comp_id(self, team_id: UUID) -> UUID | None:
        from app.models.model_team import Team
        team = self.db.query(Team).filter(Team.id == team_id).first()
        return team.comp_id if team else None

    def create(self, image_data: dict, metadata_data: dict):
        db_image = Image(**image_data)
        self.db.add(db_image)
        self.db.commit()
        self.db.refresh(db_image)

        db_metadata = ImageMetadata(**metadata_data, image_id=db_image.id)
        self.db.add(db_metadata)
        self.db.commit()
        return db_image

    def create_label_record(self, image_id: int, label_text: str):
        """Create a Label row in the label table tied to the uploaded image.

        This bridges the Image module and Danil's Label/Validation modules so that
        the voting workflow, stats, and data-validation features work correctly.
        """
        existing = self.db.query(Label).filter(Label.image_id == image_id).first()
        if existing:
            return existing
        db_label = Label(image_id=image_id, label=label_text, validated=False)
        self.db.add(db_label)
        self.db.commit()
        self.db.refresh(db_label)
        return db_label

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

    def find_by_team(self, team_id: UUID, status: str = None, author_id: UUID = None, label: str = None, skip: int = 0, limit: int = 100):
        query = self.db.query(Image).filter(Image.team_id == team_id)
        if status:
            query = query.filter(Image.status == status)
        if author_id:
            query = query.filter(Image.author_id == author_id)
        if label:
            query = query.filter(Image.label == label)
        total = query.count()
        images = query.order_by(Image.time.desc()).offset(skip).limit(limit).all()
        return images, total

    def find_by_competition(self, comp_id: UUID, status: str = None):
        from app.models.model_team import Team
        query = self.db.query(Image).join(Team, Image.team_id == Team.id).filter(Team.comp_id == comp_id)
        if status:
            query = query.filter(Image.status == status)
        total = query.count()
        return query.all(), total

    def get_stats(self, comp_id: UUID):
        from sqlalchemy import func
        from app.models.model_team import Team
        
        base_query = self.db.query(Image).join(Team, Image.team_id == Team.id).filter(Team.comp_id == comp_id)
        total = base_query.count()
        
        status_counts = self.db.query(Image.status, func.count(Image.id)).join(Team, Image.team_id == Team.id).filter(Team.comp_id == comp_id).group_by(Image.status).all()
        by_status = {str(status).split(".")[-1]: count for status, count in status_counts}

        team_counts = self.db.query(Image.team_id, func.count(Image.id)).join(Team, Image.team_id == Team.id).filter(Team.comp_id == comp_id).group_by(Image.team_id).all()
        by_team = [{"team_id": tid, "count": count} for tid, count in team_counts]
        
        # Pull label stats from the dedicated label table (Danil's Label module)
        # instead of Image.label column, so the stats align with the validation workflow.
        label_counts = (
            self.db.query(Label.label, func.count(Label.id))
            .join(Image, Label.image_id == Image.id)
            .join(Team, Image.team_id == Team.id)
            .filter(Team.comp_id == comp_id)
            .group_by(Label.label)
            .all()
        )
        by_label = [{"label": lbl, "count": count} for lbl, count in label_counts if lbl]

        return {
            "total": total,
            "by_status": by_status,
            "by_team": by_team,
            "by_label": by_label
        }

    def delete(self, image_id: int):
        img = self.find_by_id(image_id)
        if img:
            self.db.query(Label).filter(Label.image_id == image_id).delete()
            self.db.query(ImageMetadata).filter(ImageMetadata.image_id == image_id).delete()
            self.db.delete(img)
            self.db.commit()
            return True
        return False
