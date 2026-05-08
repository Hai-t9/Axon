from sqlalchemy.orm import Session

from app.models import Config, Image, ImageStatus, PhaseLog, Team


class DashboardRepository:
    def __init__(self, db: Session):
        self.db = db

    def find_phase_info(self, comp_id: int) -> PhaseLog | None:
        return (
            self.db.query(PhaseLog)
            .filter(PhaseLog.competition_id == comp_id)
            .first()
        )

    def find_config(self, comp_id: int) -> Config | None:
        return (
            self.db.query(Config)
            .filter(Config.competition_id == comp_id)
            .first()
        )

    def find_image_stats(self, comp_id: int) -> dict:
        images = (
            self.db.query(Image)
            .join(Team, Team.id == Image.team_id)
            .filter(Team.comp_id == comp_id)
            .all()
        )

        total = len(images)
        verified = sum(1 for image in images if image.status == ImageStatus.verified)
        on_hold = sum(1 for image in images if image.status == ImageStatus.onhold)
        
        team_stats = {}
        for img in images:
            if img.team_id not in team_stats:
                team_stats[img.team_id] = {"total": 0, "verified": 0}
            team_stats[img.team_id]["total"] += 1
            if img.status == ImageStatus.verified:
                team_stats[img.team_id]["verified"] += 1

        return {
            "total": total,
            "verified": verified,
            "on_hold": on_hold,
            "team_stats": team_stats
        }

    def find_team_info(self, comp_id: int) -> list[Team]:
        return (
            self.db.query(Team)
            .filter(Team.comp_id == comp_id)
            .order_by(Team.id.asc())
            .all()
        )
