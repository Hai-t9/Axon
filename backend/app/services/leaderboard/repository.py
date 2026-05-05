from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models import Evaluation, Model, Team


class LeaderboardRepository:
    def __init__(self, db: Session):
        self.db = db

    def find_best_score_per_team(self, comp_id: int, limit: int | None = None) -> list[dict]:
        rows = (
            self.db.query(
                Team.id.label("team_id"),
                Team.name.label("team_name"),
                Model.id.label("model_id"),
                Model.submitted_at.label("submitted_at"),
                Evaluation.score.label("score"),
                Evaluation.evaluated_at.label("evaluated_at"),
            )
            .join(Model, Model.team_id == Team.id)
            .join(Evaluation, Evaluation.model_id == Model.id)
            .filter(Model.competition_id == comp_id)
            .order_by(Evaluation.score.desc(), Model.submitted_at.desc())
            .all()
        )

        best_by_team: dict[int, dict] = {}
        for row in rows:
            if row.team_id not in best_by_team:
                best_by_team[row.team_id] = {
                    "team": {
                        "id": row.team_id,
                        "name": row.team_name,
                    },
                    "score": row.score,
                    "submitted_at": row.submitted_at,
                    "evaluated_at": row.evaluated_at,
                }

        ranked_entries = list(best_by_team.values())
        ranked_entries.sort(
            key=lambda item: (
                item["score"] if item["score"] is not None else float("-inf"),
                item["submitted_at"] or datetime.min.replace(tzinfo=timezone.utc),
            ),
            reverse=True,
        )

        return ranked_entries
