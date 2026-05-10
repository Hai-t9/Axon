import sys
from unittest.mock import MagicMock, patch
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, ".")

from app.main import app
from app.services.label.service import LabelService
from app.services.label.controller import get_label_service, get_auth_service


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

class TestLabelService:
    def test_create_label(self):
        repo = MagicMock()
        repo.get_image_by_id.return_value = MagicMock()
        repo.find_by_image_id.return_value = None  # no existing label
        repo.insert_label.return_value = MagicMock(
            image_id=uuid4(), label="cat", validated=False
        )
        svc = LabelService(repo)

        result = svc.create_label(uuid4(), "cat")

        assert result.label == "cat"
        assert result.validated is False
        repo.insert_label.assert_called_once()

    def test_create_label_image_not_found(self):
        repo = MagicMock()
        repo.get_image_by_id.return_value = None
        svc = LabelService(repo)

        with pytest.raises(Exception):
            svc.create_label(uuid4(), "cat")

    def test_create_label_already_exists(self):
        repo = MagicMock()
        repo.get_image_by_id.return_value = MagicMock()
        repo.find_by_image_id.return_value = MagicMock()  # label exists
        svc = LabelService(repo)

        with pytest.raises(Exception):
            svc.create_label(uuid4(), "cat")

    def test_get_label(self):
        repo = MagicMock()
        repo.find_by_image_id.return_value = MagicMock(
            image_id=uuid4(), label="dog", validated=True
        )
        svc = LabelService(repo)

        result = svc.get_label(uuid4())

        assert result.label == "dog"
        assert result.validated is True

    def test_get_label_not_found(self):
        repo = MagicMock()
        repo.find_by_image_id.return_value = None
        svc = LabelService(repo)

        with pytest.raises(Exception):
            svc.get_label(uuid4())

    def test_update_label_same_label(self):
        """Updating to the same label should be a no-op."""
        repo = MagicMock()
        repo.get_image_by_id.return_value = MagicMock()
        entry = MagicMock(image_id=uuid4(), label="cat", validated=False)
        repo.find_by_image_id.return_value = entry
        svc = LabelService(repo)

        result = svc.update_label(uuid4(), "cat")

        assert result.label == "cat"
        # modify_label should NOT be called since label didn't change
        repo.modify_label.assert_not_called()

    def test_update_label_new_label(self):
        img_id = uuid4()
        repo = MagicMock()
        repo.get_image_by_id.return_value = MagicMock()
        repo.find_by_image_id.return_value = MagicMock(
            image_id=img_id, label="cat", validated=False
        )
        repo.get_image_with_team.return_value = MagicMock(
            filepath="uploads/old/cat/img.jpg",
            team=MagicMock(
                comp_id=uuid4(),
                competition=MagicMock(name="Test Comp"),
                name="Test Team",
            ),
        )
        repo.modify_label.return_value = MagicMock(
            image_id=img_id, label="dog", validated=False
        )
        svc = LabelService(repo)

        with patch("os.path.exists", return_value=True), \
             patch("os.makedirs"), \
             patch("shutil.move"), \
             patch("app.storage.minio_client.storage_service"):
            result = svc.update_label(img_id, "dog")

        assert result.label == "dog"
        repo.modify_label.assert_called_once_with(img_id, "dog")
        repo.update_image_label.assert_called_once_with(img_id, "dog")

    def test_validate_label(self):
        repo = MagicMock()
        repo.set_label_validated.return_value = MagicMock(
            image_id=uuid4(), label="cat", validated=True
        )
        svc = LabelService(repo)

        result = svc.validate_label(uuid4())

        assert result.validated is True
        repo.set_label_validated.assert_called_once()
        repo.set_image_status.assert_called_once()

    def test_validate_label_not_found(self):
        repo = MagicMock()
        repo.set_label_validated.return_value = None
        svc = LabelService(repo)

        with pytest.raises(Exception):
            svc.validate_label(uuid4())


# ── HTTP integration tests ──────────────────────────────────────────────

class TestLabelHTTP:
    def test_create_label_endpoint(self):
        auth_mock, user_id = _make_auth_mock()
        img_id = uuid4()

        repo = MagicMock()
        repo.get_image_by_id.return_value = MagicMock(id=img_id)
        repo.find_by_image_id.return_value = None
        repo.insert_label.return_value = MagicMock(
            id=1, image_id=img_id, label="cat", validated=False
        )
        svc = LabelService(repo)

        app.dependency_overrides[get_auth_service] = lambda: auth_mock
        app.dependency_overrides[get_label_service] = lambda: svc

        with TestClient(app) as client:
            resp = client.post(
                f"/api/v1/images/{img_id}/labels",
                json={"label": "cat"},
                headers={"Authorization": "Bearer test-token"},
            )

        assert resp.status_code == 200
        body = resp.json()
        assert body["label"] == "cat"
        assert body["validated"] is False

    def test_get_label_endpoint(self):
        auth_mock, user_id = _make_auth_mock()
        img_id = uuid4()

        repo = MagicMock()
        repo.find_by_image_id.return_value = MagicMock(
            id=1, image_id=img_id, label="cat", validated=False
        )
        svc = LabelService(repo)

        app.dependency_overrides[get_auth_service] = lambda: auth_mock
        app.dependency_overrides[get_label_service] = lambda: svc

        with TestClient(app) as client:
            resp = client.get(
                f"/api/v1/images/{img_id}/labels",
                headers={"Authorization": "Bearer test-token"},
            )

        assert resp.status_code == 200
        assert resp.json()["label"] == "cat"

    def test_update_label_endpoint(self):
        auth_mock, user_id = _make_auth_mock()
        img_id = uuid4()

        repo = MagicMock()
        repo.get_image_by_id.return_value = MagicMock(id=img_id)
        repo.find_by_image_id.return_value = MagicMock(
            image_id=img_id, label="cat", validated=False
        )
        repo.modify_label.return_value = MagicMock(
            id=1, image_id=img_id, label="dog", validated=False
        )
        repo.get_image_with_team.return_value = MagicMock(
            filepath="uploads/test/cat/img.jpg",
            team=MagicMock(
                comp_id=uuid4(),
                competition=MagicMock(name="Test"),
                name="Team",
            ),
        )
        svc = LabelService(repo)

        app.dependency_overrides[get_auth_service] = lambda: auth_mock
        app.dependency_overrides[get_label_service] = lambda: svc

        with patch("os.path.exists", return_value=True), \
             patch("os.makedirs"), \
             patch("shutil.move"), \
             patch("app.storage.minio_client.storage_service"):
            with TestClient(app) as client:
                resp = client.put(
                    f"/api/v1/images/{img_id}/labels",
                    json={"label": "dog"},
                    headers={"Authorization": "Bearer test-token"},
                )

        assert resp.status_code == 200
        assert resp.json()["label"] == "dog"

    def test_validate_label_endpoint(self):
        auth_mock, user_id = _make_auth_mock()
        img_id = uuid4()

        repo = MagicMock()
        repo.set_label_validated.return_value = MagicMock(
            id=1, image_id=img_id, label="cat", validated=True
        )
        repo.get_competition_id_for_image.return_value = uuid4()
        svc = LabelService(repo)

        app.dependency_overrides[get_auth_service] = lambda: auth_mock
        app.dependency_overrides[get_label_service] = lambda: svc

        with TestClient(app) as client:
            resp = client.post(
                f"/api/v1/images/{img_id}/labels/validate",
                headers={"Authorization": "Bearer test-token"},
            )

        assert resp.status_code == 200
        assert resp.json()["validated"] is True
