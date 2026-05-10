from datetime import datetime
from uuid import UUID

from app.services.phase.service import PhaseService, PHASE_LABELS
from app.services.phase.repository import PhaseRepository

from .repository import LeaderboardRepository


class LeaderboardService:
    def __init__(self, repository: LeaderboardRepository, db=None):
        self.repository = repository
        self._db = db

    def _get_phase_info(self, comp_id: UUID) -> tuple[str, str]:
        phase_service = PhaseService(PhaseRepository(self._db))
        phase_log = phase_service.get_current_phase(comp_id)
        phase = phase_log.current_phase
        label = PHASE_LABELS.get(phase, "Unknown")
        return phase, label

    def get_leaderboard(self, comp_id: UUID, leaderboard_type: str = "public",
                        limit: int | None = None) -> dict:
        phase, phase_label = self._get_phase_info(comp_id)

        # Phase gate: only show leaderboard in Model Submission (3) or later
        phase_num = int(phase) if phase is not None else 0
        if phase_num < 3:
            return {
                "entries": [],
                "total_teams": 0,
                "type": leaderboard_type,
                "phase": phase,
                "phase_label": phase_label,
                "last_updated": datetime.utcnow(),
            }

        entries = self.repository.find_best_score_per_team(comp_id, limit)

        # Assign ranks (tied scores share the same rank)
        ranked = []
        current_rank = 0
        previous_score = None
        for index, entry in enumerate(entries, start=1):
            score = entry["score"]
            if previous_score is None or score != previous_score:
                current_rank = index
                previous_score = score
            entry["rank"] = current_rank
            ranked.append(entry)

        if limit is not None:
            ranked = ranked[:limit]

        return {
            "entries": ranked,
            "total_teams": len({
                entry["team"]["id"] for entry in ranked
            }),
            "type": leaderboard_type,
            "phase": phase,
            "phase_label": phase_label,
            "last_updated": datetime.utcnow(),
        }
