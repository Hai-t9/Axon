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
from app.models import Competition, Config, Image, Label, Team
from app.services.competition.controller import get_db as competition_get_db
from app.services.phase.controller import get_db as phase_get_db
from app.services.register.controller import get_db as register_get_db
from app.services.team.controller import get_db as team_get_db
from app.services.validation.controller import get_db as validation_get_db
from app.services.validation.repository import ValidationRepository


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
    app.dependency_overrides[validation_get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()


def _create_image(db_session, team_id: int, author_id: int, suffix: str) -> Image:
    image = Image(
        team_id=team_id,
        author_id=author_id,
        filepath=f"/tmp/validation-{suffix}.jpg",
        image_hash=f"validation-hash-{suffix}",
    )
    db_session.add(image)
    db_session.commit()
    db_session.refresh(image)
    return image


def _create_label(db_session, image_id: int, label: str) -> Label:
    entry = Label(image_id=image_id, label=label, validated=False)
    db_session.add(entry)
    db_session.commit()
    db_session.refresh(entry)
    return entry


def test_validation_flow_next_and_vote_finalize(client, db_session):
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
        json={"name": "Validation Test Competition", "description": "Test"},
    )
    assert competition_response.status_code == 200
    competition_id = competition_response.json()["id"]

    own_team_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Own Team", "user_ids": [host_id]},
    )
    assert own_team_response.status_code == 200
    own_team_id = own_team_response.json()["id"]

    other_team_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Other Team", "user_ids": []},
    )
    assert other_team_response.status_code == 200
    other_team_id = other_team_response.json()["id"]

    own_images = []
    for idx in range(6):
        image = _create_image(db_session, own_team_id, host_id, f"own-{idx}")
        _create_label(db_session, image.id, "cat")
        own_images.append(image)

    other_images = []
    for idx in range(4):
        image = _create_image(db_session, other_team_id, host_id, f"other-{idx}")
        _create_label(db_session, image.id, "dog")
        other_images.append(image)

    next_response = client.get(
        f"/api/v1/competitions/{competition_id}/validations/next",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert next_response.status_code == 200
    next_payload = next_response.json()
    assert next_payload["id"] == own_images[0].id

    target_image = own_images[0]

    voter_tokens = []
    for index in range(4):
        response = client.post(
            "/api/v1/register/signup",
            json={
                "email": f"voter{index}@example.com",
                "password": "Secure1234",
                "full_name": f"Voter {index}",
            },
        )
        assert response.status_code == 200
        voter_tokens.append(response.json()["access_token"])

    for token in voter_tokens:
        vote_response = client.post(
            f"/api/v1/images/{target_image.id}/validations",
            headers={"Authorization": f"Bearer {token}"},
            json={"label": "cat"},
        )
        assert vote_response.status_code == 200
        assert vote_response.json()["label"] == "cat"

    label_entry = db_session.query(Label).filter(Label.image_id == target_image.id).first()
    assert label_entry is not None
    assert label_entry.validated is False

    fifth_vote_response = client.post(
        f"/api/v1/images/{target_image.id}/validations",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"label": "cat"},
    )
    assert fifth_vote_response.status_code == 200

    other_user_response = client.post(
        "/api/v1/register/signup",
        json={
            "email": "voter5@example.com",
            "password": "Secure1234",
            "full_name": "Voter 5",
        },
    )
    assert other_user_response.status_code == 200
    other_token = other_user_response.json()["access_token"]

    duplicate_vote_response = client.post(
        f"/api/v1/images/{target_image.id}/validations",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"label": "cat"},
    )
    assert duplicate_vote_response.status_code == 400

    label_entry = db_session.query(Label).filter(Label.image_id == target_image.id).first()
    assert label_entry is not None
    assert label_entry.validated is True
    assert label_entry.label == "cat"


def test_validation_flow_next_handles_short_pool(client, db_session):
    signup_response = client.post(
        "/api/v1/register/signup",
        json={
            "email": "shortpool@example.com",
            "password": "Secure1234",
            "full_name": "Short Pool User",
        },
    )
    assert signup_response.status_code == 200
    payload = signup_response.json()
    token = payload["access_token"]
    user_id = payload["user"]["id"]

    competition_response = client.post(
        "/api/v1/competitions",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": "Short Batch Competition", "description": "Test"},
    )
    assert competition_response.status_code == 200
    competition_id = competition_response.json()["id"]

    own_team_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": "Own Team", "user_ids": [user_id]},
    )
    assert own_team_response.status_code == 200
    own_team_id = own_team_response.json()["id"]

    other_team_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": "Other Team", "user_ids": []},
    )
    assert other_team_response.status_code == 200
    other_team_id = other_team_response.json()["id"]

    own_images = []
    for idx in range(2):
        image = _create_image(db_session, own_team_id, user_id, f"short-own-{idx}")
        _create_label(db_session, image.id, "cat")
        own_images.append(image)

    other_image = _create_image(db_session, other_team_id, user_id, "short-other-0")
    _create_label(db_session, other_image.id, "dog")

    next_response = client.get(
        f"/api/v1/competitions/{competition_id}/validations/next",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert next_response.status_code == 200
    next_payload = next_response.json()
    assert next_payload["id"] in {image.id for image in own_images} | {other_image.id}


class _FakeValidationCache:
    def __init__(self):
        self.team_ids: dict[tuple[int, int], int] = {}
        self.thresholds: dict[int, int] = {}

    def get_participant_team_id(self, comp_id: int, participant_id: int) -> int | None:
        return self.team_ids.get((comp_id, participant_id))

    def set_participant_team_id(self, comp_id: int, participant_id: int, team_id: int) -> bool:
        self.team_ids[(comp_id, participant_id)] = team_id
        return True

    def get_validation_threshold(self, comp_id: int) -> int | None:
        return self.thresholds.get(comp_id)

    def set_validation_threshold(self, comp_id: int, threshold: int) -> bool:
        self.thresholds[comp_id] = threshold
        return True


def test_validation_cache_threshold_and_team(db_session):
    competition = Competition(name="Cache Competition", description="Test")
    db_session.add(competition)
    db_session.commit()
    db_session.refresh(competition)

    config = Config(competition_id=competition.id, max_validations=7)
    db_session.add(config)
    db_session.commit()

    participant_id = 999
    team = Team(name="Cache Team", comp_id=competition.id, user_ids=[participant_id])
    db_session.add(team)
    db_session.commit()
    db_session.refresh(team)

    cache = _FakeValidationCache()
    repository = ValidationRepository(db_session, cache)

    threshold_first = repository.find_validation_threshold(competition.id)
    assert threshold_first == 7

    config.max_validations = 12
    db_session.commit()

    threshold_cached = repository.find_validation_threshold(competition.id)
    assert threshold_cached == 7

    team_first = repository.find_participant_team(competition.id, participant_id)
    assert team_first is not None
    assert team_first.id == team.id

    team.user_ids = []
    db_session.commit()

    team_cached = repository.find_participant_team(competition.id, participant_id)
    assert team_cached is not None
    assert team_cached.id == team.id


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
