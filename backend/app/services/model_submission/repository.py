"""
FILE: backend/app/services/model_submission/repository.py
"""

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import Competition, Model, Team


class ModelSubmissionRepository:
    def __init__(self, db: Session):
        self.db = db

    # ------------------------------------------------------------------
    # Team / competition lookups
    # ------------------------------------------------------------------

    def find_team(self, team_id: int) -> Team | None:
        return self.db.query(Team).filter(Team.id == team_id).first()

    def find_competition(self, competition_id: int) -> Competition | None:
        return (
            self.db.query(Competition)
            .filter(Competition.id == competition_id)
            .first()
        )

    def team_belongs_to_competition(self, team_id: int, competition_id: int) -> bool:
        team = self.find_team(team_id)
        return team is not None and team.comp_id == competition_id

    # ------------------------------------------------------------------
    # Model CRUD
    # ------------------------------------------------------------------

    def create(
        self,
        team_id: int,
        competition_id: int,
        docker_img_filepath: str,
    ) -> Model:
        model = Model(
            team_id=team_id,
            competition_id=competition_id,
            docker_img_filepath=docker_img_filepath,
        )
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return model

    def find_by_id(self, model_id: int) -> Model | None:
        return self.db.query(Model).filter(Model.id == model_id).first()

    def find_by_team(self, team_id: int) -> list[Model]:
        return (
            self.db.query(Model)
            .filter(Model.team_id == team_id)
            .order_by(Model.submitted_at.desc())
            .all()
        )

    def find_by_competition(self, competition_id: int) -> list[Model]:
        return (
            self.db.query(Model)
            .filter(Model.competition_id == competition_id)
            .order_by(Model.submitted_at.desc())
            .all()
        )

    def count_by_team(self, team_id: int) -> int:
        return int(
            self.db.query(func.count(Model.id))
            .filter(Model.team_id == team_id)
            .scalar()
            or 0
        )

    def delete(self, model: Model) -> None:
        self.db.delete(model)
        self.db.commit()