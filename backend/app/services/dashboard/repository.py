from datetime import datetime

from sqlalchemy.orm import Session
from uuid import UUID

from app.models import Config, Image, ImageStatus, PhaseLog, Team


class DashboardRepository:
    def __init__(self, db: Session):
        self.db = db

    def find_phase_info(self, comp_id: UUID) -> PhaseLog | None:
        return (
            self.db.query(PhaseLog)
            .filter(PhaseLog.competition_id == comp_id)
            .first()
        )

    def ensure_phase_info(self, comp_id: UUID) -> PhaseLog:
        existing = self.find_phase_info(comp_id)
        if existing:
            return existing
        now = datetime.utcnow().isoformat()
        entry = PhaseLog(
            competition_id=comp_id,
            current_phase="0",
            phase_dates={
                "transition_mode": "manual",
                "deadlines": {},
                "timeline": [
                    {"phase": "0", "start": now, "deadline": None, "status": "in_progress"}
                ],
                "history": [],
            },
        )
        self.db.add(entry)
        self.db.commit()
        self.db.refresh(entry)
        return entry

    def find_config(self, comp_id: UUID) -> Config | None:
        return (
            self.db.query(Config)
            .filter(Config.competition_id == comp_id)
            .first()
        )

    def find_image_stats(self, comp_id: UUID) -> dict:
        images = (
            self.db.query(Image)
            .join(Team, Team.id == Image.team_id)
            .filter(Team.comp_id == comp_id)
            .all()
        )

        total = len(images)
        verified = sum(1 for image in images if image.status == ImageStatus.verified)
        on_hold = sum(1 for image in images if image.status == ImageStatus.onhold)

        return {
            "total": total,
            "verified": verified,
            "on_hold": on_hold,
        }

    def find_team_info(self, comp_id: UUID) -> list[Team]:
        return (
            self.db.query(Team)
            .filter(Team.comp_id == comp_id)
            .order_by(Team.id.asc())
            .all()
        )

    def find_team_for_participant(self, comp_id: UUID, participant_id: UUID) -> Team | None:
        from sqlalchemy import func
        from app.models import User

        user = self.db.query(User).filter(User.id == participant_id).first()
        if not user:
            return None
        user_email = user.email.strip().lower()

        teams = (
            self.db.query(Team)
            .filter(Team.comp_id == comp_id)
            .order_by(Team.id.asc())
            .all()
        )
        for team in teams:
            emails_dict = team.user_emails or {}
            if user_email in {k.lower() for k in emails_dict.keys()}:
                return team
        return None

    def find_team_image_stats(self, team_id: UUID) -> dict:
        images = self.db.query(Image).filter(Image.team_id == team_id).all()

        total = len(images)
        verified = sum(1 for image in images if image.status == ImageStatus.verified)
        on_hold = sum(1 for image in images if image.status == ImageStatus.onhold)

        return {
            "total": total,
            "verified": verified,
            "on_hold": on_hold,
        }

    def find_device_stats(self, comp_id: UUID) -> dict:
        """Return device counts across all images in the competition."""
        images = (
            self.db.query(Image)
            .join(Team, Team.id == Image.team_id)
            .filter(Team.comp_id == comp_id)
            .all()
        )
        devices = {}
        for img in images:
            if img.device:
                devices[img.device] = devices.get(img.device, 0) + 1
        return devices

    def find_label_distribution(self, comp_id: UUID) -> dict:
        """Return count of images per label in the competition."""
        images = (
            self.db.query(Image)
            .join(Team, Team.id == Image.team_id)
            .filter(Team.comp_id == comp_id)
            .all()
        )
        labels = {}
        for img in images:
            if img.label:
                labels[img.label] = labels.get(img.label, 0) + 1
        return labels

    def find_locations(self, comp_id: UUID) -> list[dict]:
        """Return locations (GPS info) for images in the competition."""
        from app.models import ImageMetadata
        metadata = (
            self.db.query(ImageMetadata)
            .join(Image, Image.id == ImageMetadata.image_id)
            .join(Team, Team.id == Image.team_id)
            .filter(Team.comp_id == comp_id, ImageMetadata.gps_info.isnot(None))
            .all()
        )
        return [{
            "image_id": str(m.image_id),
            "gps_info": m.gps_info,
            "location_metadata": {
                "make": m.make,
                "model": m.camera_model,
                "datetime": m.date_time.isoformat() if m.date_time else None,
            }
        } for m in metadata]

    def find_team_device_stats(self, team_id: UUID) -> dict:
        """Return device counts for a specific team."""
        images = self.db.query(Image).filter(Image.team_id == team_id).all()
        devices = {}
        for img in images:
            if img.device:
                devices[img.device] = devices.get(img.device, 0) + 1
        return devices

    def find_team_label_distribution(self, team_id: UUID) -> dict:
        """Return label distribution for a specific team."""
        images = self.db.query(Image).filter(Image.team_id == team_id).all()
        labels = {}
        for img in images:
            if img.label:
                labels[img.label] = labels.get(img.label, 0) + 1
        return labels

    def find_team_locations(self, team_id: UUID) -> list[dict]:
        """Return locations (GPS info) for a specific team's images."""
        from app.models import ImageMetadata
        metadata = (
            self.db.query(ImageMetadata)
            .join(Image, Image.id == ImageMetadata.image_id)
            .filter(Image.team_id == team_id, ImageMetadata.gps_info.isnot(None))
            .all()
        )
        return [{
            "image_id": str(m.image_id),
            "gps_info": m.gps_info,
            "location_metadata": {
                "make": m.make,
                "model": m.camera_model,
                "datetime": m.date_time.isoformat() if m.date_time else None,
            }
        } for m in metadata]
