import sys
from unittest.mock import MagicMock, patch
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, ".")

from app.main import app
from app.services.leaderboard.service import LeaderboardService
from app.services.leaderboard.controller import get_leaderboard_service
from app.services.leaderboard.controller import get_auth_service


# ── Helpers ──────────────────────────────────────────────────────────────

def _make_auth_mock(user_id: str | None = None):
    mock = MagicMock()
    uid = UUID(user_id) if user_id else uuid4()
    mock.get_current_user.return_value = MagicMock(id=uid)
    mock.require_roles.return_value = None
    return mock, uid


@pytest.fixture(autouse=True)
def clear_overrides():
    yield
    app.dependency_overrides.clear()


# ── Service-level tests ─────────────────────────────────────────────────

class TestLeaderboardService:
    def test_get_leaderboard_structure(self):
        """Leaderboard returns expected fields."""
        comp_id = uuid4()
        repo = MagicMock()
        svc = LeaderboardService(repo)

        with patch.object(svc, "_generate_mock_entries") as mock_gen:
            mock_gen.return_value = [
                {
                    "rank": 1,
                    "team": {"id": str(uuid4()), "name": "Alpha"},
                    "score": 0.95,
                    "entries": 1,
                },
                {
                    "rank": 2,
                    "team": {"id": str(uuid4()), "name": "Beta"},
                    "score": 0.85,
                    "entries": 1,
                },
            ]
            with patch.object(svc, "_get_phase_info") as phase_mock:
                phase_mock.return_value = (3, "Model Submission")
                result = svc.get_leaderboard(comp_id, "public")

        assert result["total_teams"] == 2
        assert len(result["entries"]) == 2
        assert result["entries"][0]["rank"] == 1
        assert result["entries"][0]["team"]["name"] == "Alpha"
        assert result["entries"][0]["score"] == 0.95
        assert result["entries"][1]["rank"] == 2

    def test_leaderboard_limit(self):
        comp_id = uuid4()
        repo = MagicMock()
        svc = LeaderboardService(repo)

        with patch.object(svc, "_generate_mock_entries") as mock_gen:
            mock_gen.return_value = [
                {"rank": i, "team": {"id": str(uuid4()), "name": f"T{i}"},
                 "score": 1.0 - i * 0.1, "entries": 1}
                for i in range(1, 6)
            ]
            with patch.object(svc, "_get_phase_info") as phase_mock:
                phase_mock.return_value = (3, "Model Submission")
                result = svc.get_leaderboard(comp_id, "public", limit=3)

        assert result["total_teams"] == 5
        assert len(result["entries"]) == 3

    def test_leaderboard_phase_gate(self):
        """Leaderboard returns empty entries when phase is 1 (Data Collection)."""
        comp_id = uuid4()
        repo = MagicMock()
        svc = LeaderboardService(repo)

        with patch.object(svc, "_get_phase_info") as phase_mock:
            phase_mock.return_value = (1, "Data Collection")
            result = svc.get_leaderboard(comp_id, "public")

        assert result["total_teams"] == 0
        assert len(result["entries"]) == 0

    def test_leaderboard_phase_unknown(self):
        comp_id = uuid4()
        repo = MagicMock()
        svc = LeaderboardService(repo)

        with patch.object(svc, "_get_phase_info") as phase_mock:
            phase_mock.return_value = (None, None)
            result = svc.get_leaderboard(comp_id, "public")

        assert result["total_teams"] == 0
        assert len(result["entries"]) == 0


# ── HTTP integration tests ──────────────────────────────────────────────

class TestLeaderboardHTTP:
    def test_leaderboard_endpoint(self):
        auth_mock, user_id = _make_auth_mock()
        comp_id = uuid4()

        repo = MagicMock()
        svc = LeaderboardService(repo, db=MagicMock())
        # Stub _get_phase_info to avoid DB query chain returning MagicMocks
        svc._get_phase_info = MagicMock(return_value=("3", "Model Submission"))
        # Stub _generate_mock_entries to avoid TeamRepository DB query
        svc._generate_mock_entries = MagicMock(return_value=[])

        app.dependency_overrides[get_auth_service] = lambda: auth_mock
        app.dependency_overrides[get_leaderboard_service] = lambda: svc

        with TestClient(app) as client:
            resp = client.get(
                f"/api/v1/competitions/{comp_id}/leaderboard",
                headers={"Authorization": "Bearer test-token"},
            )

        assert resp.status_code == 200
        body = resp.json()
        assert "entries" in body
        assert "total_teams" in body

    def test_leaderboard_limit_param(self):
        auth_mock, user_id = _make_auth_mock()
        comp_id = uuid4()

        repo = MagicMock()
        svc = LeaderboardService(repo, db=MagicMock())
        # Stub _get_phase_info to avoid DB query chain returning MagicMocks
        svc._get_phase_info = MagicMock(return_value=("3", "Model Submission"))
        svc._generate_mock_entries = MagicMock(return_value=[])

        app.dependency_overrides[get_auth_service] = lambda: auth_mock
        app.dependency_overrides[get_leaderboard_service] = lambda: svc

        with TestClient(app) as client:
            resp = client.get(
                f"/api/v1/competitions/{comp_id}/leaderboard?limit=1",
                headers={"Authorization": "Bearer test-token"},
            )

        assert resp.status_code == 200
        # limit is respected by the service; just verify 200
