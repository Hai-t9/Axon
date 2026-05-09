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
from app.models import Config, Image, ImageStatus, PhaseLog, Role, RoleType, Team
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

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()


def _create_image(db_session, team_id: str, author_id: str, status: ImageStatus):
    image = Image(
        team_id=UUID(team_id),
        author_id=UUID(author_id),
        filepath=f"/tmp/dashboard-role-{team_id}-{author_id}-{status.value}.jpg",
        image_hash=f"dashboard-role-hash-{team_id}-{author_id}-{status.value}",
        status=status,
    )
    db_session.add(image)
    db_session.commit()
    db_session.refresh(image)
    return image


def test_dashboard_role_based_response(client, db_session):
    host_response = client.post(
        "/api/v1/register/signup",
        json={
            "email": "host@example.com",
            "password": "Secure1234",
            "full_name": "Host User",
        },
    )
    assert host_response.status_code == 200
    host_token = host_response.json()["access_token"]
    host_id = host_response.json()["user"]["id"]

    participant_response = client.post(
        "/api/v1/register/signup",
        json={
            "email": "participant@example.com",
            "password": "Secure1234",
            "full_name": "Participant User",
        },
    )
    assert participant_response.status_code == 200
    participant_token = participant_response.json()["access_token"]
    participant_id = participant_response.json()["user"]["id"]

    competition_response = client.post(
        "/api/v1/competitions",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Dashboard Role Competition", "description": "Test"},
    )
    assert competition_response.status_code == 200
    competition_id = competition_response.json()["id"]

    db_session.add(
        Role(
            user_id=UUID(participant_id),
            competition_id=UUID(competition_id),
            role=RoleType.participant,
        )
    )
    db_session.commit()

    team_one_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Alpha Team", "user_emails": {"participant@example.com": True}},
    )
    assert team_one_response.status_code == 200
    team_one_id = team_one_response.json()["id"]

    team_two_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Beta Team", "user_emails": {"host@example.com": True}},
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

    _create_image(db_session, team_one_id, participant_id, ImageStatus.verified)
    _create_image(db_session, team_one_id, participant_id, ImageStatus.onhold)
    _create_image(db_session, team_two_id, host_id, ImageStatus.verified)

    config = (
        db_session.query(Config)
        .filter(Config.competition_id == UUID(competition_id))
        .first()
    )
    assert config is not None
    config.labels = {"cat": 1}
    config.data_ex = "data_ex"
    config.overview = "overview"
    config.terms_conditions = "terms"
    config.data_md = "data_md"
    config.data_format = "data_format"
    config.scoring_ex = "scoring_ex"
    config.evaluation = "evaluation"
    config.duplicate_threshhold = 0.42
    config.max_validations = 7
    db_session.commit()

    host_dashboard = client.get(
        f"/api/v1/competitions/{competition_id}/dashboard",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert host_dashboard.status_code == 200
    host_payload = host_dashboard.json()

    assert host_payload["image_stats"] == {"total": 3, "verified": 2, "on_hold": 1}
    assert host_payload["team_info"]["total"] == 2
    assert len(host_payload["team_info"]["items"]) == 2
    assert host_payload["config"]["scoring_ex"] == "scoring_ex"
    assert host_payload["config"]["evaluation"] == "evaluation"
    assert host_payload["config"]["duplicate_threshhold"] == 0.42
    assert host_payload["config"]["max_validations"] == 7

    participant_dashboard = client.get(
        f"/api/v1/competitions/{competition_id}/dashboard",
        headers={"Authorization": f"Bearer {participant_token}"},
    )
    assert participant_dashboard.status_code == 200
    participant_payload = participant_dashboard.json()

    assert participant_payload["image_stats"] == {"total": 2, "verified": 1, "on_hold": 1}
    assert participant_payload["team_info"]["id"] == team_one_id
    assert participant_payload["team_info"]["comp_id"] == competition_id
    assert participant_payload["team_info"]["user_emails"] == {"participant@example.com": True}

    participant_config = participant_payload["config"]
    assert participant_config["labels"] == {"cat": 1}
    assert participant_config["data_ex"] == "data_ex"
    assert participant_config["overview"] == "overview"
    assert participant_config["terms_conditions"] == "terms"
    assert participant_config["data_md"] == "data_md"
    assert participant_config["data_format"] == "data_format"

    forbidden_keys = {
        "id",
        "competition_id",
        "scoring_ex",
        "evaluation",
        "duplicate_threshhold",
        "max_validations",
    }
    assert forbidden_keys.isdisjoint(participant_config.keys())
    assert "items" not in participant_payload["team_info"]
    assert "total" not in participant_payload["team_info"]


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
