from sqlalchemy import func
from sqlalchemy.orm import Session
from uuid import UUID
import logging

from app.models import Image, Model, Team, User

logger = logging.getLogger(__name__)


class TeamRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, team_id: UUID) -> Team | None:
        return self.db.query(Team).filter(Team.id == team_id).first()

    def get_by_name(self, comp_id: UUID, name: str) -> Team | None:
        return (
            self.db.query(Team)
            .filter(Team.comp_id == comp_id, Team.name == name)
            .first()
        )

    def list_by_competition(self, comp_id: UUID, offset: int, limit: int) -> list[Team]:
        return (
            self.db.query(Team)
            .filter(Team.comp_id == comp_id)
            .order_by(Team.id.asc())
            .offset(offset)
            .limit(limit)
            .all()
        )

    def count_by_competition(self, comp_id: UUID) -> int:
        return int(
            self.db.query(func.count(Team.id)).filter(Team.comp_id == comp_id).scalar()
            or 0
        )

    def create(self, team_data: dict) -> Team:
        team = Team(**team_data)
        self.db.add(team)
        self.db.commit()
        self.db.refresh(team)
        return team

    def update(self, team: Team, updates: dict) -> Team:
        for key, value in updates.items():
            setattr(team, key, value)
        self.db.commit()
        self.db.refresh(team)
        return team

    def delete(self, team: Team) -> None:
        self.db.delete(team)
        self.db.commit()

    def get_user_by_email(self, email: str) -> User | None:
        return self.db.query(User).filter(func.lower(User.email) == email.strip().lower()).first()

    def set_user_emails(self, team: Team, user_emails: dict) -> Team:
        team.user_emails = user_emails
        self.db.commit()
        self.db.refresh(team)
        return team

    def get_members_by_emails(self, emails: list[str]) -> list[User]:
        if not emails:
            return []
        lower_emails = [e.lower() for e in emails]
        return self.db.query(User).filter(func.lower(User.email).in_(lower_emails)).all()

    def count_images_by_team(self, team_id: UUID) -> int:
        return int(
            self.db.query(func.count(Image.id)).filter(Image.team_id == team_id).scalar()
            or 0
        )

    def count_models_by_team(self, team_id: UUID) -> int:
        return int(
            self.db.query(func.count(Model.id)).filter(Model.team_id == team_id).scalar()
            or 0
        )
