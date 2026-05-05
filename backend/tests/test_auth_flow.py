import os
import sys

import pytest

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.main import app
from app.services.competition.controller import get_db as competition_get_db
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

    with TestClient(app) as client:
        yield client

    app.dependency_overrides.clear()


def test_auth_flow_register_login_and_roles(client):
    signup_response = client.post(
        "/api/v1/register/signup",
        json={
            "email": "host@example.com",
            "password": "Secure1234",
            "full_name": "Host User",
        },
    )
    assert signup_response.status_code == 200
    signup_payload = signup_response.json()
    host_token = signup_payload["access_token"]
    assert signup_payload["user"]["email"] == "host@example.com"

    login_response = client.post(
        "/api/v1/register/login",
        json={
            "email": "host@example.com",
            "password": "Secure1234",
        },
    )
    assert login_response.status_code == 200
    assert login_response.json()["access_token"]

    invalid_token_response = client.get(
        "/api/v1/competitions",
        headers={"Authorization": "Bearer invalid.token"},
    )
    assert invalid_token_response.status_code == 401

    competition_response = client.post(
        "/api/v1/competitions",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Axon Test Competition", "description": "Test"},
    )
    assert competition_response.status_code == 200
    competition_id = competition_response.json()["id"]

    list_response = client.get(
        "/api/v1/competitions",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert list_response.status_code == 200
    assert list_response.json()["total"] == 1

    other_user_response = client.post(
        "/api/v1/register/signup",
        json={
            "email": "user@example.com",
            "password": "Secure1234",
            "full_name": "Other User",
        },
    )
    assert other_user_response.status_code == 200
    other_token = other_user_response.json()["access_token"]

    forbidden_response = client.put(
        f"/api/v1/competitions/{competition_id}/config",
        headers={"Authorization": f"Bearer {other_token}"},
        json={"labels": {"cat": 1}},
    )
    assert forbidden_response.status_code == 403

    config_response = client.put(
        f"/api/v1/competitions/{competition_id}/config",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"labels": {"cat": 1}},
    )
    assert config_response.status_code == 200
    assert config_response.json()["labels"] == {"cat": 1}


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
