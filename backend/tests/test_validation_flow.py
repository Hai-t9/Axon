import os
import sys
import random

import pytest
from uuid import UUID, uuid4
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


def _create_image(db_session, team_id: str, author_id: str, suffix: str) -> Image:
    image = Image(
        team_id=UUID(team_id),
        author_id=UUID(author_id),
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


def _deterministic_shuffle(image_ids: list[int], participant_id: UUID) -> list[int]:
    shuffled = list(image_ids)
    random.Random(str(participant_id)).shuffle(shuffled)
    return shuffled


def _build_expected_validation_assignments(db_session, competition_id: UUID) -> tuple[dict[str, list[int]], dict[str, list[int]]]:
    """
    Simulate the Round-Robin assignment algorithm:
    - Fetch all teams and all images
    - For each image, assign it threshold times across teams in round-robin fashion
    - Return the per-team master lists and per-participant shuffled lists
    """
    from app.services.validation.repository import ValidationRepository

    repository = ValidationRepository(db_session)
    config = db_session.query(Config).filter(Config.competition_id == competition_id).first()
    threshold = int(config.max_validations) if config and config.max_validations is not None else 5

    teams = repository.fetch_all_teams(competition_id)
    images = repository.fetch_all_competition_images(competition_id)
    
    if not teams or not images:
        return {}, {}

    # Round-Robin assignment
    team_assignments: dict[str, list[int]] = {str(team.id): [] for team in teams}
    team_index = 0
    for image_id in images:
        for _ in range(threshold):
            team = teams[team_index % len(teams)]
            team_assignments[str(team.id)].append(image_id)
            team_index += 1

    # Per-participant assignments (shuffled)
    participant_assignments: dict[str, list[int]] = {}
    for team in teams:
        for raw_participant_id in team.user_ids or []:
            participant_id = UUID(str(raw_participant_id))
            participant_assignments[str(participant_id)] = _deterministic_shuffle(
                team_assignments[str(team.id)],
                participant_id,
            )

    return team_assignments, participant_assignments


def test_validation_batch_generation_list_and_finalize_flow(client, db_session):
    host_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "validation-host@example.com",
            "password": "Secure1234",
            "full_name": "Validation Host",
        },
    )
    assert host_signup.status_code == 200
    host_payload = host_signup.json()
    host_token = host_payload["access_token"]
    host_id = host_payload["user"]["id"]

    teammate_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "validation-teammate@example.com",
            "password": "Secure1234",
            "full_name": "Validation Teammate",
        },
    )
    assert teammate_signup.status_code == 200
    teammate_payload = teammate_signup.json()
    teammate_token = teammate_payload["access_token"]
    teammate_id = teammate_payload["user"]["id"]

    competition_response = client.post(
        "/api/v1/competitions",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Validation Batch Competition", "description": "Test"},
    )
    assert competition_response.status_code == 200
    competition_id = UUID(competition_response.json()["id"])

    config = db_session.query(Config).filter(Config.competition_id == competition_id).first()
    if config is None:
        config = Config(competition_id=competition_id, max_validations=3)
        db_session.add(config)
    else:
        config.max_validations = 3
    db_session.commit()

    own_team_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Validation Own Team", "user_ids": [host_id, teammate_id]},
    )
    assert own_team_response.status_code == 200
    own_team_id = UUID(own_team_response.json()["id"])

    other_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "validation-other@example.com",
            "password": "Secure1234",
            "full_name": "Validation Other",
        },
    )
    assert other_signup.status_code == 200
    other_user_id = other_signup.json()["user"]["id"]

    other_team_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Validation Other Team", "user_ids": [other_user_id]},
    )
    assert other_team_response.status_code == 200
    other_team_id = UUID(other_team_response.json()["id"])

    own_images = []
    for idx in range(6):
        image = _create_image(db_session, str(own_team_id), host_id, f"batch-own-{idx}")
        _create_label(db_session, image.id, "cat")
        own_images.append(image)

    for idx in range(4):
        image = _create_image(db_session, str(other_team_id), other_user_id, f"batch-other-{idx}")
        _create_label(db_session, image.id, "dog")

    generate_response = client.post(
        f"/api/v1/competitions/{competition_id}/validations/generate",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert generate_response.status_code == 200
    assert generate_response.json() == {"success": True}

    team_assignments, participant_assignments = _build_expected_validation_assignments(
        db_session,
        competition_id,
    )

    host_list_response = client.get(
        f"/api/v1/competitions/{competition_id}/validations/list",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert host_list_response.status_code == 200
    host_list = host_list_response.json()["image_ids"]

    teammate_list_response = client.get(
        f"/api/v1/competitions/{competition_id}/validations/list",
        headers={"Authorization": f"Bearer {teammate_token}"},
    )
    assert teammate_list_response.status_code == 200
    teammate_list = teammate_list_response.json()["image_ids"]

    assert host_list == participant_assignments[host_id]
    assert teammate_list == participant_assignments[teammate_id]
    assert sorted(host_list) == sorted(teammate_list)
    assert host_list == client.get(
        f"/api/v1/competitions/{competition_id}/validations/list",
        headers={"Authorization": f"Bearer {host_token}"},
    ).json()["image_ids"]
    assert team_assignments[str(own_team_id)] == sorted(team_assignments[str(own_team_id)], key=lambda value: team_assignments[str(own_team_id)].index(value))

    target_image_id = host_list[0]

    voter_tokens = [host_token, teammate_token]
    for index in range(1):
        voter_signup = client.post(
            "/api/v1/register/signup",
            json={
                "email": f"validation-voter-{index}@example.com",
                "password": "Secure1234",
                "full_name": f"Validation Voter {index}",
            },
        )
        assert voter_signup.status_code == 200
        voter_tokens.append(voter_signup.json()["access_token"])

    for token in voter_tokens:
        vote_response = client.post(
            f"/api/v1/images/{target_image_id}/validations",
            headers={"Authorization": f"Bearer {token}"},
            json={"label": "cat"},
        )
        assert vote_response.status_code == 200
        assert vote_response.json()["label"] == "cat"

    label_entry = db_session.query(Label).filter(Label.image_id == target_image_id).first()
    assert label_entry is not None
    assert label_entry.validated is True
    assert label_entry.label == "cat"

    pending_response = client.get(
        f"/api/v1/competitions/{competition_id}/validations/pending",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert pending_response.status_code == 200
    pending_ids = {item["id"] for item in pending_response.json()["images"]}
    assert target_image_id not in pending_ids


class _FakeRedisClient:
    def __init__(self):
        self.rpush_calls: list[tuple[str, list[str]]]=[]
        self.expire_calls: list[tuple[str, int]] = []
        self.storage: dict[str, list[str]] = {}

    def delete(self, key: str) -> int:
        self.storage.pop(key, None)
        return 1

    def rpush(self, key: str, *values: str) -> int:
        self.rpush_calls.append((key, list(values)))
        self.storage.setdefault(key, []).extend(values)
        return len(self.storage[key])

    def expire(self, key: str, ttl_seconds: int) -> bool:
        self.expire_calls.append((key, ttl_seconds))
        return True

    def lrange(self, key: str, start: int, end: int) -> list[str]:
        values = self.storage.get(key, [])
        if end == -1:
            return values[start:]
        return values[start : end + 1]


class _FakeValidationCacheForAssignments:
    def __init__(self):
        self.client = _FakeRedisClient()


def test_validation_assignment_redis_keys_and_ttl(db_session):
    competition = Competition(name="Redis Key Competition", description="Test")
    db_session.add(competition)
    db_session.commit()
    db_session.refresh(competition)

    participant_a = uuid4()
    participant_b = uuid4()
    team = Team(
        name="Redis Team",
        comp_id=competition.id,
        user_ids=[str(participant_a), str(participant_b)],
    )
    db_session.add(team)
    db_session.commit()
    db_session.refresh(team)

    for index in range(3):
        image = Image(
            team_id=team.id,
            author_id=participant_a,
            filepath=f"/tmp/redis-key-{index}.jpg",
            image_hash=f"redis-key-hash-{index}",
        )
        db_session.add(image)
        db_session.commit()
        _create_label(db_session, image.id, "cat")

    repository = ValidationRepository(db_session, _FakeValidationCacheForAssignments())
    # Store only the team master list; per-participant shuffling is done at retrieval time.
    assert repository.store_team_assignments(team.id, [1, 2, 3]) is True

    fake_client = repository.cache.client
    assert fake_client.rpush_calls == [
        (f"validation:team:{team.id}", ["1", "2", "3"]),
    ]
    assert fake_client.expire_calls == [
        (f"validation:team:{team.id}", 86400),
    ]
    assert repository.get_team_assignments(team.id) == [1, 2, 3]


def test_round_robin_assignment(db_session):
    """Test that Round-Robin assignment distributes images evenly across teams."""
    competition = Competition(name="Round Robin Test", description="Test")
    db_session.add(competition)
    db_session.commit()
    db_session.refresh(competition)

    # Create 3 teams
    teams = []
    for i in range(3):
        team = Team(
            name=f"Team {i}",
            comp_id=competition.id,
            user_ids=[str(uuid4())],
        )
        db_session.add(team)
        db_session.commit()
        db_session.refresh(team)
        teams.append(team)

    # Create 4 images
    images = []
    for i in range(4):
        image = Image(
            team_id=teams[0].id,
            author_id=UUID(teams[0].user_ids[0]),
            filepath=f"/tmp/round-robin-{i}.jpg",
            image_hash=f"rr-hash-{i}",
        )
        db_session.add(image)
        db_session.commit()
        db_session.refresh(image)
        images.append(image)
        _create_label(db_session, image.id, "test")

    # Create config with threshold
    config = Config(competition_id=competition.id, max_validations=3)
    db_session.add(config)
    db_session.commit()

    # Run assignment
    from app.services.validation.repository import ValidationRepository
    from app.services.validation.service import ValidationService
    from app.services.label.service import LabelService
    from app.services.label.repository import LabelRepository

    repository = ValidationRepository(db_session)
    label_service = LabelService(LabelRepository(db_session))
    service = ValidationService(repository, label_service)

    result = service.generate_assignments(competition.id)
    assert result == {"success": True}

    # Verify Round-Robin: each image should appear exactly threshold times
    # With 4 images and threshold 3, total assignments = 4 * 3 = 12
    # Distributed across 3 teams = 4 images per team
    team_assignments = {}
    for team in teams:
        team_assignments[str(team.id)] = repository.get_team_assignments(team.id)

    # Count how many times each image appears across all teams
    image_counts = {}
    for team_id, image_list in team_assignments.items():
        for img_id in image_list:
            image_counts[img_id] = image_counts.get(img_id, 0) + 1

    # Each image should appear exactly threshold times
    for img_id, count in image_counts.items():
        assert count == 3, f"Image {img_id} appears {count} times, expected 3"

    # Verify round-robin distribution
    expected_assignments = {
        str(teams[0].id): [1, 2, 3, 4],  # First round-robin cycle for team 0
        str(teams[1].id): [1, 2, 3, 4],  # Second cycle for team 1
        str(teams[2].id): [1, 2, 3, 4],  # Third cycle for team 2
    }

    # Check that all teams got the same images in the same order
    for team_id, expected in expected_assignments.items():
        assert team_assignments[team_id] == expected, f"Team {team_id} got {team_assignments[team_id]}, expected {expected}"


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
