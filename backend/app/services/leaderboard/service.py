import random
from datetime import datetime
from uuid import UUID

from app.core.exceptions import NotFoundError
from app.services.phase.service import PhaseService, PHASE_LABELS
from app.services.phase.repository import PhaseRepository
from app.services.team.repository import TeamRepository

from .repository import LeaderboardRepository


class LeaderboardService:
    def __init__(self, repository: LeaderboardRepository, db=None):
        self.repository = repository
        self._db = db

    def _get_phase_info(self, comp_id: UUID) -> tuple[str, str]:
        """Get current phase and label. Returns (phase, label)."""
        phase_service = PhaseService(PhaseRepository(self._db))
        phase_log = phase_service.get_current_phase(comp_id)
        phase = phase_log.current_phase
        label = PHASE_LABELS.get(phase, "Unknown")
        return phase, label

    def _generate_mock_entries(self, comp_id: UUID, leaderboard_type: str) -> list[dict]:
        """Generate mock leaderboard data from teams in the competition."""
        team_repo = TeamRepository(self._db)
        all_teams = team_repo.list_by_competition(comp_id, 0, 100)

        if not all_teams:
            raise NotFoundError("No teams found in this competition")

        entries = []
        for i, team in enumerate(all_teams):
            team_data = {"id": str(team.id), "name": team.name}

            if leaderboard_type == "private":
                protocols = ["standard", "loto", "toto"]
                for protocol in protocols:
                    base = random.uniform(0.5, 0.98)
                    entries.append({
                        "team": team_data,
                        "score": round(base * 100, 2),
                        "accuracy": round(base, 4),
                        "precision": round(base + random.uniform(-0.05, 0.05), 4),
                        "recall": round(base + random.uniform(-0.05, 0.05), 4),
                        "f1_score": round(base + random.uniform(-0.03, 0.03), 4),
                        "protocol": protocol,
                        "submitted_at": datetime.utcnow(),
                        "models_submitted": random.randint(1, 5),
                    })
            else:
                entries.append({
                    "team": team_data,
                    "score": round(random.uniform(50, 100), 2),
                    "submitted_at": datetime.utcnow(),
                    "models_submitted": random.randint(1, 5),
                    "protocol": None,
                })

        # Sort by score descending
        entries.sort(key=lambda e: e["score"], reverse=True)

        # Assign ranks
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

        return ranked

    def get_leaderboard(self, comp_id: UUID, leaderboard_type: str = "public",
                        limit: int | None = None) -> dict:
        phase, phase_label = self._get_phase_info(comp_id)

        # Phase gate: only show leaderboard in Model Submission (3) or later
        phase_num = int(phase)
        if phase_num < 3:
            return {
                "entries": [],
                "total_teams": 0,
                "type": leaderboard_type,
                "phase": phase,
                "phase_label": phase_label,
                "last_updated": datetime.utcnow(),
            }

        mock_entries = self._generate_mock_entries(comp_id, leaderboard_type)

        if limit is not None:
            mock_entries = mock_entries[:limit]

        total_teams = len({
            entry["team"]["id"] for entry in mock_entries
        })

        return {
            "entries": mock_entries,
            "total_teams": total_teams,
            "type": leaderboard_type,
            "phase": phase,
            "phase_label": phase_label,
            "last_updated": datetime.utcnow(),
        }
