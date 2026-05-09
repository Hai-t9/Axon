from sqlalchemy import func
from sqlalchemy.orm import Session
from uuid import UUID

from app.models import Competition, Config, Role, User


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

    def list_competitions_for_user(self, user_id: UUID, offset: int, limit: int) -> list[Competition]:
        from sqlalchemy import cast, String, or_
        from app.models.model_team import Team

        user_id_str = str(user_id)
        role_subq = self.db.query(Role.competition_id).filter(Role.user_id == user_id)
        team_subq = self.db.query(Team.comp_id).filter(cast(Team.user_ids, String).like(f'%{user_id_str}%'))
        
        return (
            self.db.query(Competition)
            .filter(
                or_(
                    Competition.id.in_(role_subq),
                    Competition.id.in_(team_subq)
                )
            )
            .order_by(Competition.id.desc())
            .offset(offset)
            .limit(limit)
            .all()
        )

    def count_competitions_for_user(self, user_id: UUID) -> int:
        from sqlalchemy import cast, String, or_
        from app.models.model_team import Team

        user_id_str = str(user_id)
        role_subq = self.db.query(Role.competition_id).filter(Role.user_id == user_id)
        team_subq = self.db.query(Team.comp_id).filter(cast(Team.user_ids, String).like(f'%{user_id_str}%'))
        
        return int(
            self.db.query(func.count(Competition.id))
            .filter(
                or_(
                    Competition.id.in_(role_subq),
                    Competition.id.in_(team_subq)
                )
            )
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

    def create_role(self, user_id: UUID, competition_id: UUID, role) -> Role:
        entry = Role(user_id=user_id, competition_id=competition_id, role=role)
        self.db.add(entry)
        self.db.commit()
        self.db.refresh(entry)
        return entry

