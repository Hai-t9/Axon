from sqlalchemy import func
from sqlalchemy.orm import Session
from uuid import UUID

from app.models import Competition, Config, Role, Team, User


class CompetitionRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, competition_id: UUID) -> Competition | None:
        return (
            self.db.query(Competition)
            .filter(Competition.id == competition_id)
            .first()
        )

    def get_by_name(self, name: str) -> Competition | None:
        return self.db.query(Competition).filter(Competition.name == name).first()

    def get_by_invitation_link(self, link: str) -> Competition | None:
        return self.db.query(Competition).filter(Competition.invitation_link == link).first()

    def get_user_by_email(self, email: str) -> User | None:
        return self.db.query(User).filter(func.lower(User.email) == email.lower()).first()

    def get_teams_for_competition(self, competition_id: UUID) -> list[Team]:
        return self.db.query(Team).filter(Team.comp_id == competition_id).all()

    def get_user_by_email_by_id(self, user_id: UUID) -> User | None:
        return self.db.query(User).filter(User.id == user_id).first()

    def list_competitions_for_user(self, user_id: UUID, offset: int, limit: int) -> list[Competition]:
        role_subq = self.db.query(Role.competition_id).filter(Role.user_id == user_id)

        return (
            self.db.query(Competition)
            .filter(Competition.id.in_(role_subq))
            .order_by(Competition.id.desc())
            .offset(offset)
            .limit(limit)
            .all()
        )

    def count_competitions_for_user(self, user_id: UUID) -> int:
        role_subq = self.db.query(Role.competition_id).filter(Role.user_id == user_id)

        return int(
            self.db.query(func.count(Competition.id))
            .filter(Competition.id.in_(role_subq))
            .scalar() or 0
        )

    def create(self, competition_data: dict) -> Competition:
        competition = Competition(**competition_data)
        self.db.add(competition)
        self.db.commit()
        self.db.refresh(competition)
        return competition

    def update(self, competition: Competition, updates: dict) -> Competition:
        for key, value in updates.items():
            setattr(competition, key, value)
        self.db.commit()
        self.db.refresh(competition)
        return competition

    def delete(self, competition: Competition) -> None:
        self.db.delete(competition)
        self.db.commit()

    def get_config(self, competition_id: UUID) -> Config | None:
        return (
            self.db.query(Config)
            .filter(Config.competition_id == competition_id)
            .first()
        )

    def create_config(self, competition_id: UUID, config_data: dict) -> Config:
        config = Config(competition_id=competition_id, **config_data)
        self.db.add(config)
        self.db.commit()
        self.db.refresh(config)
        return config

    def update_config(self, config: Config, updates: dict) -> Config:
        for key, value in updates.items():
            setattr(config, key, value)
        self.db.commit()
        self.db.refresh(config)
        return config

    def get_role(self, user_id: UUID, competition_id: UUID) -> Role | None:
        return (
            self.db.query(Role)
            .filter(Role.user_id == user_id, Role.competition_id == competition_id)
            .first()
        )

    def remove_role(self, user_id: UUID, competition_id: UUID) -> None:
        self.db.query(Role).filter(
            Role.user_id == user_id, Role.competition_id == competition_id
        ).delete()
        self.db.commit()

    def create_role(self, user_id: UUID, competition_id: UUID, role) -> Role:
        entry = Role(user_id=user_id, competition_id=competition_id, role=role)
        self.db.add(entry)
        self.db.commit()
        self.db.refresh(entry)
        return entry

    def get_team_for_user(self, competition_id: UUID, user_id: UUID) -> Team | None:
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user:
            return None
        user_email = user.email.strip().lower()
        teams = self.db.query(Team).filter(Team.comp_id == competition_id).all()
        for team in teams:
            emails_dict = team.user_emails or {}
            if user_email in {k.lower() for k in emails_dict.keys()}:
                return team
        return None

