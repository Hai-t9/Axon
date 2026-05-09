import os
import sys

import pytest
from uuid import UUID
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
from app.services.dashboard.controller import get_db as dashboard_get_db
from app.services.phase.controller import get_db as phase_get_db
from app.services.register.controller import get_db as register_get_db
from app.services.team.controller import get_db as team_get_db


@pytest.fixture()
def db_session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)

    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture()
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[register_get_db] = override_get_db
    app.dependency_overrides[competition_get_db] = override_get_db
    app.dependency_overrides[team_get_db] = override_get_db
    app.dependency_overrides[phase_get_db] = override_get_db
    app.dependency_overrides[dashboard_get_db] = override_get_db

    with TestClient(app) as client:
        yield client

    app.dependency_overrides.clear()


def _create_image(db_session, team_id: str, author_id: str, status: ImageStatus):
    image = Image(
        team_id=UUID(team_id),
        author_id=UUID(author_id),
        filepath=f"/tmp/dashboard_{team_id}_{author_id}_{status.value}.jpg",
        image_hash=f"dashboard_hash_{team_id}_{author_id}_{status.value}",
        status=status,
    )
    db_session.add(image)
    db_session.commit()
    db_session.refresh(image)
    return image


def test_dashboard_flow_returns_competition_summary(client, db_session):
    signup_response = client.post(
        "/api/v1/register/signup",
        json={
            "email": "host@example.com",
            "password": "Secure1234",
            "full_name": "Host User",
        },
    )
    assert signup_response.status_code == 200
    host_payload = signup_response.json()
    host_token = host_payload["access_token"]
    host_id = host_payload["user"]["id"]

    competition_response = client.post(
        "/api/v1/competitions",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Dashboard Test Competition", "description": "Test"},
    )
    assert competition_response.status_code == 200
    competition_id = competition_response.json()["id"]

    team_one_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Alpha Team", "user_emails": {"host@example.com": 0}},
    )
    assert team_one_response.status_code == 200
    team_one_id = team_one_response.json()["id"]

    team_two_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Beta Team", "user_emails": {"host@example.com": 0}},
    )
    assert team_two_response.status_code == 200
    team_two_id = team_two_response.json()["id"]

    db_session.add(
        PhaseLog(
            competition_id=UUID(competition_id),
            current_phase="active",
            phase_dates={"timeline": [], "history": []},
        )
    )
    db_session.commit()

    _create_image(db_session, team_one_id, host_id, ImageStatus.verified)
    _create_image(db_session, team_two_id, host_id, ImageStatus.onhold)

    dashboard_response = client.get(
        f"/api/v1/competitions/{competition_id}/dashboard",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert dashboard_response.status_code == 200
    payload = dashboard_response.json()

    assert payload["phase_info"]["current_phase"] == "active"
    assert payload["config"]["competition_id"] == competition_id
    assert payload["image_stats"] == {"total": 2, "verified": 1, "on_hold": 1}
    assert payload["team_info"]["total"] == 2
    assert len(payload["team_info"]["items"]) == 2


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
