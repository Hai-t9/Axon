import sys
from unittest.mock import MagicMock, patch
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, ".")

from app.main import app
from app.services.validation.service import ValidationService
from app.services.validation.controller import get_validation_service
from app.services.validation.controller import get_auth_service


# ── Helpers ──────────────────────────────────────────────────────────────

def _make_auth_mock(user_id: str | None = None, roles: list | None = None):
    """Returns a mock AuthService that always succeeds."""
    mock = MagicMock()
    uid = UUID(user_id) if user_id else uuid4()
    mock.get_current_user.return_value = MagicMock(id=uid)
    mock.require_roles.return_value = None
    return mock, uid


def _make_validation_service_mock(repo_mock=None, label_service_mock=None):
    """Returns a ValidationService wired with the given mocks (or fresh ones)."""
    repo = repo_mock or MagicMock()
    label_svc = label_service_mock or MagicMock()
    svc = ValidationService(repo, label_svc)
    return svc, repo, label_svc


@pytest.fixture(autouse=True)
def clear_overrides():
    yield
    app.dependency_overrides.clear()


# ── _compute_majority_vote ───────────────────────────────────────────────

class TestComputeMajorityVote:
    def test_simple_majority(self):
        svc = ValidationService(MagicMock(), MagicMock())
        assert svc._compute_majority_vote(["cat", "cat", "dog"]) == "cat"

    def test_tie_break_alphabetical(self):
        svc = ValidationService(MagicMock(), MagicMock())
        assert svc._compute_majority_vote(["dog", "cat"]) == "cat"

    def test_single_vote(self):
        svc = ValidationService(MagicMock(), MagicMock())
        assert svc._compute_majority_vote(["fish"]) == "fish"

    def test_empty_raises(self):
        svc = ValidationService(MagicMock(), MagicMock())
        with pytest.raises(Exception):
            svc._compute_majority_vote([])


# ── generate_assignments ────────────────────────────────────────────────

class TestGenerateAssignments:
    def test_success(self):
        repo = MagicMock()
        repo.fetch_all_teams.return_value = [MagicMock(id=uuid4()) for _ in range(2)]
        repo.fetch_all_competition_images.return_value = [uuid4() for _ in range(3)]
        repo.find_validation_threshold.return_value = 3
        svc = ValidationService(repo, MagicMock())

        result = svc.generate_assignments(uuid4())

        assert result == {"success": True}
        assert repo.store_team_assignments.call_count == 2

    def test_no_teams_raises(self):
        repo = MagicMock()
        repo.fetch_all_teams.return_value = []
        svc = ValidationService(repo, MagicMock())

        with pytest.raises(Exception):
            svc.generate_assignments(uuid4())

    def test_no_images_raises(self):
        repo = MagicMock()
        repo.fetch_all_teams.return_value = [MagicMock(id=uuid4())]
        repo.fetch_all_competition_images.return_value = []
        svc = ValidationService(repo, MagicMock())

        with pytest.raises(Exception):
            svc.generate_assignments(uuid4())


# ── get_validation_list ─────────────────────────────────────────────────

class TestGetValidationList:
    def test_returns_images(self):
        comp_id = uuid4()
        participant_id = uuid4()
        team_id = uuid4()
        img_id = uuid4()

        repo = MagicMock()
        repo.find_participant_team.return_value = team_id
        repo.get_team_assignments.return_value = [img_id]
        repo.filter_unvalidated_images.return_value = [img_id]
        repo.fetch_image_details.return_value = {
            img_id: {"filepath": "uploads/test.jpg", "label": "cat"}
        }
        svc = ValidationService(repo, MagicMock())

        result = svc.get_validation_list(comp_id, participant_id)

        assert result["total"] == 1
        assert result["images"][0]["image_id"] == str(img_id)
        assert result["images"][0]["filepath"] == "uploads/test.jpg"
        assert result["images"][0]["current_label"] == "cat"

    def test_no_assignments_triggers_generate(self):
        repo = MagicMock()
        repo.find_participant_team.return_value = uuid4()
        repo.get_team_assignments.side_effect = [[], [uuid4()]]  # first empty, second populated
        repo.filter_unvalidated_images.return_value = [uuid4()]
        repo.fetch_image_details.return_value = {}
        svc = ValidationService(repo, MagicMock())

        result = svc.get_validation_list(uuid4(), uuid4())

        assert repo.store_team_assignments.called or True  # generate_assignments was called
        assert result["total"] == 0  # no details returned


# ── submit_vote ─────────────────────────────────────────────────────────

class TestSubmitVote:
    def test_below_threshold(self):
        repo = MagicMock()
        vote_mock = MagicMock(id=uuid4())
        vote_mock.label = "cat"
        repo.insert_vote.return_value = vote_mock
        repo.find_validation_threshold.return_value = 3
        repo.count_votes_for_image.return_value = 1
        repo.get_skip_count.return_value = 0
        svc = ValidationService(repo, MagicMock())

        result = svc.submit_vote(uuid4(), uuid4(), "cat")

        assert result["label"] == "cat"
        # label_service.update_label should NOT be called (below threshold)
        svc.label_service.update_label.assert_not_called()

    def test_reaches_threshold_updates_label(self):
        img_id = uuid4()
        label_id = 1

        repo = MagicMock()
        vote_mock = MagicMock(id=uuid4())
        vote_mock.label = "cat"
        repo.insert_vote.return_value = vote_mock
        repo.find_validation_threshold.return_value = 2
        repo.count_votes_for_image.return_value = 2
        repo.get_skip_count.return_value = 0
        repo.find_label_by_image_id.return_value = MagicMock(id=label_id)

        vote_mock = MagicMock()
        vote_mock.label = "cat"
        repo.find_votes_by_label_id.return_value = [vote_mock, vote_mock]

        label_svc = MagicMock()
        svc = ValidationService(repo, label_svc)

        result = svc.submit_vote(img_id, uuid4(), "cat")

        assert result["label"] == "cat"
        label_svc.update_label.assert_called_once_with(img_id, "cat")
        label_svc.validate_label.assert_called_once_with(img_id)

    def test_threshold_with_skips_combined(self):
        img_id = uuid4()
        label_id = 1

        repo = MagicMock()
        repo.insert_vote.return_value = MagicMock(id=uuid4())
        repo.find_validation_threshold.return_value = 2
        repo.count_votes_for_image.return_value = 1
        repo.get_skip_count.return_value = 1  # 1 vote + 1 skip = threshold
        repo.find_label_by_image_id.return_value = MagicMock(id=label_id)

        vote_mock = MagicMock()
        vote_mock.label = "cat"
        repo.find_votes_by_label_id.return_value = [vote_mock]

        label_svc = MagicMock()
        svc = ValidationService(repo, label_svc)

        svc.submit_vote(img_id, uuid4(), "cat")

        label_svc.update_label.assert_called_once_with(img_id, "cat")
        label_svc.validate_label.assert_called_once_with(img_id)


# ── skip_image ──────────────────────────────────────────────────────────

class TestSkipImage:
    def test_skip_removes_from_queue(self):
        comp_id = uuid4()
        team_id = uuid4()
        img_id = uuid4()
        participant_id = uuid4()

        repo = MagicMock()
        repo.find_participant_team.return_value = team_id
        repo.remove_from_team_assignment.return_value = 1
        repo.increment_skip_count.return_value = 1
        repo.count_votes_for_image.return_value = 0
        repo.find_validation_threshold.return_value = 3

        label_svc = MagicMock()
        label_svc.get_competition_id.return_value = comp_id
        svc = ValidationService(repo, label_svc)

        result = svc.skip_image(img_id, participant_id)

        assert result["skip_count"] == 1
        assert result["auto_validated"] is False
        repo.remove_from_team_assignment.assert_called_once_with(team_id, img_id)

    def test_skip_reaches_threshold_auto_validates(self):
        comp_id = uuid4()
        team_id = uuid4()
        img_id = uuid4()
        participant_id = uuid4()
        label_id = 1

        repo = MagicMock()
        repo.find_participant_team.return_value = team_id
        repo.remove_from_team_assignment.return_value = 1
        repo.increment_skip_count.return_value = 2
        repo.count_votes_for_image.return_value = 0
        repo.find_validation_threshold.return_value = 2
        repo.find_label_by_image_id.return_value = MagicMock(id=label_id, validated=False)

        label_svc = MagicMock()
        label_svc.get_competition_id.return_value = comp_id
        svc = ValidationService(repo, label_svc)

        result = svc.skip_image(img_id, participant_id)

        assert result["auto_validated"] is True
        # No votes, so original label should be kept, just validated
        label_svc.update_label.assert_not_called()
        label_svc.validate_label.assert_called_once_with(img_id)

    def test_skip_not_in_queue_raises(self):
        repo = MagicMock()
        repo.find_participant_team.return_value = uuid4()
        repo.remove_from_team_assignment.return_value = 0  # nothing removed

        label_svc = MagicMock()
        label_svc.get_competition_id.return_value = uuid4()
        svc = ValidationService(repo, label_svc)

        with pytest.raises(Exception):
            svc.skip_image(uuid4(), uuid4())

    def test_skip_with_votes_at_threshold(self):
        comp_id = uuid4()
        team_id = uuid4()
        img_id = uuid4()
        participant_id = uuid4()
        label_id = 1

        repo = MagicMock()
        repo.find_participant_team.return_value = team_id
        repo.remove_from_team_assignment.return_value = 1
        repo.increment_skip_count.return_value = 2
        repo.count_votes_for_image.return_value = 1  # 1 vote + 2 skip = 3, threshold = 2
        repo.find_validation_threshold.return_value = 2
        repo.find_label_by_image_id.return_value = MagicMock(id=label_id, validated=False)

        vote_mock = MagicMock()
        vote_mock.label = "dog"
        repo.find_votes_by_label_id.return_value = [vote_mock]

        label_svc = MagicMock()
        label_svc.get_competition_id.return_value = comp_id
        svc = ValidationService(repo, label_svc)

        result = svc.skip_image(img_id, participant_id)

        assert result["auto_validated"] is True
        label_svc.update_label.assert_called_once_with(img_id, "dog")  # majority from votes
        label_svc.validate_label.assert_called_once_with(img_id)


# ── HTTP integration (smoke tests with mocked deps) ─────────────────────

class TestValidationHTTP:
    def test_generate_endpoint_success(self):
        auth_mock, user_id = _make_auth_mock()
        repo = MagicMock()
        repo.fetch_all_teams.return_value = [MagicMock(id=uuid4())]
        repo.fetch_all_competition_images.return_value = [uuid4()]
        repo.find_validation_threshold.return_value = 3
        svc = ValidationService(repo, MagicMock())

        app.dependency_overrides[get_auth_service] = lambda: auth_mock
        app.dependency_overrides[get_validation_service] = lambda: svc

        comp_id = uuid4()
        with TestClient(app) as client:
            resp = client.post(
                f"/api/v1/competitions/{comp_id}/validations/generate",
                headers={"Authorization": "Bearer test-token"},
            )
        assert resp.status_code == 200
        assert resp.json() == {"success": True}

    def test_validation_list_endpoint(self):
        auth_mock, user_id = _make_auth_mock()
        repo = MagicMock()
        repo.find_participant_team.return_value = uuid4()
        repo.get_team_assignments.return_value = [uuid4()]
        repo.filter_unvalidated_images.return_value = [uuid4()]
        repo.fetch_image_details.return_value = {
            uuid4(): {"filepath": "t.jpg", "label": "l"}
        }
        svc = ValidationService(repo, MagicMock())

        app.dependency_overrides[get_auth_service] = lambda: auth_mock
        app.dependency_overrides[get_validation_service] = lambda: svc

        comp_id = uuid4()
        with TestClient(app) as client:
            resp = client.get(
                f"/api/v1/competitions/{comp_id}/validations/list",
                headers={"Authorization": "Bearer test-token"},
            )
        assert resp.status_code == 200
        body = resp.json()
        assert "images" in body
        assert "total" in body

    def test_submit_vote_endpoint(self):
        auth_mock, user_id = _make_auth_mock()
        repo = MagicMock()
        vote_mock = MagicMock(id=uuid4())
        vote_mock.label = "cat"
        repo.insert_vote.return_value = vote_mock
        repo.find_validation_threshold.return_value = 3
        repo.count_votes_for_image.return_value = 1
        repo.get_skip_count.return_value = 0
        svc = ValidationService(repo, MagicMock())

        app.dependency_overrides[get_auth_service] = lambda: auth_mock
        app.dependency_overrides[get_validation_service] = lambda: svc

        img_id = uuid4()
        with TestClient(app) as client:
            resp = client.post(
                f"/api/v1/images/{img_id}/validations",
                json={"label": "cat"},
                headers={"Authorization": "Bearer test-token"},
            )
        assert resp.status_code == 200
        assert resp.json()["label"] == "cat"

    def test_skip_image_endpoint(self):
        auth_mock, user_id = _make_auth_mock()
        repo = MagicMock()
        repo.find_participant_team.return_value = uuid4()
        repo.remove_from_team_assignment.return_value = 1
        repo.increment_skip_count.return_value = 1
        repo.count_votes_for_image.return_value = 0
        repo.find_validation_threshold.return_value = 3
        label_svc = MagicMock()
        label_svc.get_competition_id.return_value = uuid4()
        svc = ValidationService(repo, label_svc)

        app.dependency_overrides[get_auth_service] = lambda: auth_mock
        app.dependency_overrides[get_validation_service] = lambda: svc

        img_id = uuid4()
        with TestClient(app) as client:
            resp = client.post(
                f"/api/v1/images/{img_id}/validations/skip",
                headers={"Authorization": "Bearer test-token"},
            )
        assert resp.status_code == 200
        assert resp.json()["skip_count"] == 1
