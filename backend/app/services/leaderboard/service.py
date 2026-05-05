from datetime import datetime

from app.core.exceptions import NotFoundError

from .repository import LeaderboardRepository


class LeaderboardService:
    def __init__(self, repository: LeaderboardRepository):
        self.repository = repository

    def get_leaderboard(self, comp_id: int, limit: int | None = None) -> dict:
        entries = self.repository.find_best_score_per_team(comp_id, limit)
        if not entries:
            raise NotFoundError("Leaderboard not found")

        ranked_entries = []
        current_rank = 0
        previous_score = None
        for index, entry in enumerate(entries, start=1):
            score = entry["score"]
            if previous_score is None or score != previous_score:
                current_rank = index
                previous_score = score

            ranked_entries.append(
                {
                    "rank": current_rank,
                    "team": entry["team"],
                    "score": score,
                    "submitted_at": entry["submitted_at"],
                }
            )

        total_teams = len({entry["team"]["id"] for entry in entries})
        if limit is not None:
            ranked_entries = ranked_entries[:limit]

        return {
            "entries": ranked_entries,
            "total_teams": total_teams,
            "last_updated": datetime.utcnow(),
        }
