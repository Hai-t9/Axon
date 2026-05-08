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
        teams = (
            self.db.query(Team)
            .filter(Team.comp_id == comp_id)
            .order_by(Team.id.asc())
            .all()
        )
        for team in teams:
            if str(participant_id) in (team.user_ids or []):
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
