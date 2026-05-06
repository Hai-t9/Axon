"""
FILE: backend/app/services/evaluation/repository.py
"""

from datetime import datetime

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import Evaluation, Image, Label, Model, Team


class EvaluationRepository:
    def __init__(self, db: Session):
        self.db = db

    # ------------------------------------------------------------------
    # Model lookups
    # ------------------------------------------------------------------

    def find_model(self, model_id: int) -> Model | None:
        return self.db.query(Model).filter(Model.id == model_id).first()

    def find_models_by_competition(self, competition_id: int) -> list[Model]:
        return (
            self.db.query(Model)
            .filter(Model.competition_id == competition_id)
            .order_by(Model.submitted_at.desc())
            .all()
        )

    # ------------------------------------------------------------------
    # Evaluation CRUD
    # ------------------------------------------------------------------

    def find_by_model_id(self, model_id: int) -> Evaluation | None:
        return (
            self.db.query(Evaluation)
            .filter(Evaluation.model_id == model_id)
            .first()
        )

    def create_evaluation(self, model_id: int, score: float) -> Evaluation:
        evaluation = Evaluation(model_id=model_id, score=score)
        self.db.add(evaluation)
        self.db.commit()
        self.db.refresh(evaluation)
        return evaluation

    def update_evaluation(self, evaluation: Evaluation, score: float) -> Evaluation:
        evaluation.score = score
        evaluation.evaluated_at = datetime.utcnow()
        self.db.commit()
        self.db.refresh(evaluation)
        return evaluation

    # ------------------------------------------------------------------
    # Dataset helpers for LOTO / TOTO protocols
    # ------------------------------------------------------------------

    def get_validated_images_by_team(self, team_id: int) -> list[dict]:
        """Return validated images (filepath + label) for a specific team."""
        rows = (
            self.db.query(Image.id, Image.filepath, Label.label)
            .join(Label, Label.image_id == Image.id)
            .filter(Image.team_id == team_id, Label.validated.is_(True))
            .all()
        )
        return [{"id": r.id, "filepath": r.filepath, "label": r.label} for r in rows]

    def get_teams_in_competition(self, competition_id: int) -> list[Team]:
        return (
            self.db.query(Team)
            .filter(Team.comp_id == competition_id)
            .all()
        )

    def get_all_validated_images_for_competition(
        self, competition_id: int
    ) -> list[dict]:
        """Return ALL validated images across all teams including team_id for splitting."""
        rows = (
            self.db.query(Image.id, Image.filepath, Image.team_id, Label.label)
            .join(Team, Team.id == Image.team_id)
            .join(Label, Label.image_id == Image.id)
            .filter(Team.comp_id == competition_id, Label.validated.is_(True))
            .all()
        )
        return [
            {"id": r.id, "filepath": r.filepath, "team_id": r.team_id, "label": r.label}
            for r in rows
        ]

    def count_validated_images(self, competition_id: int) -> int:
        return int(
            self.db.query(func.count(Image.id))
            .join(Team, Team.id == Image.team_id)
            .join(Label, Label.image_id == Image.id)
            .filter(Team.comp_id == competition_id, Label.validated.is_(True))
            .scalar()
            or 0
        )