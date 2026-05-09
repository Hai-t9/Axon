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
from app.models import Evaluation, Model
from app.models.model_model import ModelFormat
from uuid import UUID
from app.services.competition.controller import get_db as competition_get_db
from app.services.leaderboard.controller import get_db as leaderboard_get_db
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
    app.dependency_overrides[leaderboard_get_db] = override_get_db

    with TestClient(app) as client:
        yield client

    app.dependency_overrides.clear()


def _to_uuid(value) -> UUID:
    if isinstance(value, UUID):
        return value
    return UUID(str(value))


def _create_model_and_evaluation(
    db_session,
    team_id,
    competition_id,
    docker_img_filepath: str,
    score: float,
    submitted_by=None,
):
    team_uuid = _to_uuid(team_id)
    comp_uuid = _to_uuid(competition_id)
    submitted_by_uuid = _to_uuid(submitted_by) if submitted_by is not None else None

    model = Model(
        team_id=team_uuid,
        competition_id=comp_uuid,
        submitted_by=submitted_by_uuid,
        filename=os.path.basename(docker_img_filepath),
        storage_path=docker_img_filepath,
        model_hash=f"hash_{os.path.basename(docker_img_filepath)}",
        format=ModelFormat.ONNX,
        framework_version="1.0",
        size_mb=1.0,
        version=1,
    )
    db_session.add(model)
    db_session.commit()
    db_session.refresh(model)

    evaluation = Evaluation(model_id=model.id, score=score)
    db_session.add(evaluation)
    db_session.commit()
    db_session.refresh(evaluation)
    return model, evaluation


def test_leaderboard_flow_ranks_best_scores(client, db_session):
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
        json={"name": "Leaderboard Test Competition", "description": "Test"},
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

    _create_model_and_evaluation(
        db_session,
        team_id=team_one_id,
        competition_id=competition_id,
        docker_img_filepath="/tmp/team-one-v1.tar",
        score=0.4,
        submitted_by=host_id,
    )
    _create_model_and_evaluation(
        db_session,
        team_id=team_one_id,
        competition_id=competition_id,
        docker_img_filepath="/tmp/team-one-v2.tar",
        score=0.9,
        submitted_by=host_id,
    )
    _create_model_and_evaluation(
        db_session,
        team_id=team_two_id,
        competition_id=competition_id,
        docker_img_filepath="/tmp/team-two-v1.tar",
        score=0.7,
        submitted_by=host_id,
    )

    leaderboard_response = client.get(
        f"/api/v1/competitions/{competition_id}/leaderboard",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert leaderboard_response.status_code == 200
    payload = leaderboard_response.json()
    assert payload["total_teams"] == 2
    assert len(payload["entries"]) == 2
    assert payload["entries"][0]["rank"] == 1
    assert payload["entries"][0]["team"]["name"] == "Alpha Team"
    assert payload["entries"][0]["score"] == 0.9
    assert payload["entries"][1]["rank"] == 2
    assert payload["entries"][1]["team"]["name"] == "Beta Team"

    limited_response = client.get(
        f"/api/v1/competitions/{competition_id}/leaderboard?limit=1",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert limited_response.status_code == 200
    assert len(limited_response.json()["entries"]) == 1
    assert limited_response.json()["total_teams"] == 2


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
