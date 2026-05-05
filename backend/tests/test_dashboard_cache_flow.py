import os
import sys

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

from app.core.database import Base
from app.main import app
from app.models import Image, ImageStatus, PhaseLog
from app.services.competition.controller import get_db as competition_get_db
from app.services.dashboard.controller import get_cache as dashboard_get_cache
from app.services.dashboard.controller import get_db as dashboard_get_db
from app.services.phase.controller import get_db as phase_get_db
from app.services.register.controller import get_db as register_get_db
from app.services.team.controller import get_db as team_get_db


class FakeDashboardCache:
    def __init__(self):
        self.store = {}

    def _key(self, comp_id: int) -> str:
        return f"dashboard:{comp_id}"

    def set_dashboard(self, comp_id: int, data: dict):
        self.store[self._key(comp_id)] = {
            "cached_at": "2026-01-01T00:00:00",
            "data": data,
        }
        return True

    def get_dashboard(self, comp_id: int):
        return self.store.get(self._key(comp_id))

    def clear_dashboard(self, comp_id: int):
        return self.store.pop(self._key(comp_id), None) is not None


@pytest.fixture()
def db_session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    testing_session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    session = testing_session_local()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture()
def client(db_session):
    cache = FakeDashboardCache()

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    def override_get_cache():
        return cache

    app.dependency_overrides[register_get_db] = override_get_db
    app.dependency_overrides[competition_get_db] = override_get_db
    app.dependency_overrides[team_get_db] = override_get_db
    app.dependency_overrides[phase_get_db] = override_get_db
    app.dependency_overrides[dashboard_get_db] = override_get_db
    app.dependency_overrides[dashboard_get_cache] = override_get_cache

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()


def _create_image(db_session, team_id: int, author_id: int):
    image = Image(
        team_id=team_id,
        author_id=author_id,
        filepath=f"/tmp/dashboard-cache-{team_id}-{author_id}.jpg",
        image_hash=f"dashboard-cache-hash-{team_id}-{author_id}",
        status=ImageStatus.verified,
    )
    db_session.add(image)
    db_session.commit()


def test_dashboard_cache_endpoints_flow(client, db_session):
    signup_response = client.post(
        "/api/v1/register/signup",
        json={
            "email": "host@example.com",
            "password": "Secure1234",
            "full_name": "Host User",
        },
    )
    assert signup_response.status_code == 200
    host_token = signup_response.json()["access_token"]
    host_id = signup_response.json()["user"]["id"]

    competition_response = client.post(
        "/api/v1/competitions",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Dashboard Cache Competition", "description": "Test"},
    )
    assert competition_response.status_code == 200
    competition_id = competition_response.json()["id"]

    team_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Cache Team", "user_ids": [host_id]},
    )
    assert team_response.status_code == 200
    team_id = team_response.json()["id"]

    db_session.add(
        PhaseLog(
            competition_id=competition_id,
            current_phase="active",
            phase_dates={"timeline": [], "history": []},
        )
    )
    db_session.commit()

    _create_image(db_session, team_id=team_id, author_id=host_id)

    fresh_response = client.get(
        f"/api/v1/competitions/{competition_id}/dashboard",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert fresh_response.status_code == 200

    cached_response = client.get(
        f"/api/v1/competitions/{competition_id}/dashboard/cache",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert cached_response.status_code == 200
    assert cached_response.json()["data"]["phase_info"]["current_phase"] == "active"

    clear_response = client.delete(
        f"/api/v1/competitions/{competition_id}/dashboard/cache",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert clear_response.status_code == 200
    assert clear_response.json() == {"cleared": True}

    missing_cached_response = client.get(
        f"/api/v1/competitions/{competition_id}/dashboard/cache",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert missing_cached_response.status_code == 404


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
