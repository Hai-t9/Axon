import os
import sys
import random
from pathlib import Path

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


@pytest.fixture(autouse=True)
def reset_validation_in_memory_store():
    from app.services.validation import repository as validation_repo
    from app.core.cache import get_validation_cache

    # Clear in-memory store before test
    validation_repo._memory_assignment_store.clear()
    validation_repo._memory_assignment_expiry.clear()
    
    # Clear Redis before test if available
    cache = get_validation_cache()
    if cache and cache.client:
        try:
            # Delete all validation-related keys
            keys = cache.client.keys("validation:*")
            if keys:
                cache.client.delete(*keys)
        except Exception:
            pass
    
    yield
    
    # Clear in-memory store after test
    validation_repo._memory_assignment_store.clear()
    validation_repo._memory_assignment_expiry.clear()
    
    # Clear Redis after test if available
    if cache and cache.client:
        try:
            keys = cache.client.keys("validation:*")
            if keys:
                cache.client.delete(*keys)
        except Exception:
            pass


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


def _create_image(db_session, team_id: str, author_id: str, suffix: str,
                   comp_id: str | None = None, label: str | None = None) -> Image:
    team_uuid = UUID(team_id)
    author_uuid = UUID(author_id)
    filename = f"validation-{suffix}.jpg"

    if comp_id is not None:
        safe_label = label.replace(" ", "_").lower() if label else "unlabeled"
        filepath = f"uploads/{comp_id}/images/{team_uuid}/{safe_label}/{filename}"
    else:
        filepath = f"uploads/{filename}"

    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    Path(filepath).touch()

    image = Image(
        team_id=team_uuid,
        author_id=author_uuid,
        filepath=filepath,
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
    from sqlalchemy import func
    from app.models import User
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
        for email in (team.user_emails or {}).keys():
            user = db_session.query(User).filter(func.lower(User.email) == email.lower()).first()
            if user:
                participant_id = user.id
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
        json={"name": "Validation Own Team", "user_emails": {"validation-host@example.com": 0, "validation-teammate@example.com": 0}},
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
        json={"name": "Validation Other Team", "user_emails": {"validation-other@example.com": 0}},
    )
    assert other_team_response.status_code == 200
    other_team_id = UUID(other_team_response.json()["id"])

    created_files = []
    own_images = []
    try:
        for idx in range(6):
            image = _create_image(db_session, str(own_team_id), host_id, f"batch-own-{idx}",
                                   comp_id=str(competition_id), label="cat")
            created_files.append(image.filepath)
            _create_label(db_session, image.id, "cat")
            own_images.append(image)

        for idx in range(4):
            image = _create_image(db_session, str(other_team_id), other_user_id, f"batch-other-{idx}",
                                   comp_id=str(competition_id), label="dog")
            created_files.append(image.filepath)
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
    finally:
        for fp in created_files:
            if fp and os.path.exists(fp):
                os.remove(fp)
                try:
                    os.removedirs(os.path.dirname(fp))
                except OSError:
                    pass


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
        user_emails={"redis-a@test.com": 0, "redis-b@test.com": 0},
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
            user_emails={f"team{i}@test.com": 0},
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
            author_id=uuid4(),
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


def test_skip_image_removes_from_queue_and_increments_skip_count(client, db_session):
    """Test that skipping an image removes it from the team's queue and increments skip count."""
    # Setup: Create host, teams, images
    host_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "skip-host@example.com",
            "password": "Secure1234",
            "full_name": "Skip Host",
        },
    )
    assert host_signup.status_code == 200
    host_token = host_signup.json()["access_token"]
    host_id = host_signup.json()["user"]["id"]

    participant_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "skip-participant@example.com",
            "password": "Secure1234",
            "full_name": "Skip Participant",
        },
    )
    assert participant_signup.status_code == 200
    participant_token = participant_signup.json()["access_token"]
    participant_id = participant_signup.json()["user"]["id"]

    competition_response = client.post(
        "/api/v1/competitions",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Skip Test Competition", "description": "Test skip logic"},
    )
    assert competition_response.status_code == 200
    competition_id = UUID(competition_response.json()["id"])

    # Set validation threshold to 2
    config = db_session.query(Config).filter(Config.competition_id == competition_id).first()
    if config is None:
        config = Config(competition_id=competition_id, max_validations=2)
        db_session.add(config)
    else:
        config.max_validations = 2
    db_session.commit()

    # Create team with host and participant
    team_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={
            "name": "Skip Test Team",
            "user_emails": {
                "skip-host@example.com": 0,
                "skip-participant@example.com": 0,
            },
        },
    )
    assert team_response.status_code == 200
    team_id = UUID(team_response.json()["id"])

    # Create 3 images
    images = []
    for idx in range(3):
        image = _create_image(db_session, str(team_id), host_id, f"skip-test-{idx}")
        _create_label(db_session, image.id, "cat")
        images.append(image)

    # Generate assignments
    gen_response = client.post(
        f"/api/v1/competitions/{competition_id}/validations/generate",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert gen_response.status_code == 200

    # Get validation list
    list_response = client.get(
        f"/api/v1/competitions/{competition_id}/validations/list",
        headers={"Authorization": f"Bearer {participant_token}"},
    )
    assert list_response.status_code == 200
    initial_list = list_response.json()["image_ids"]
    # With round-robin: 3 images × 2 threshold = 6 assignments to the team
    assert len(initial_list) == 6, f"Should have 6 images (3 images × threshold 2), got {initial_list}"

    # Skip the first unique image in the list
    skip_target = initial_list[0]
    skip_response = client.post(
        f"/api/v1/images/{skip_target}/validations/skip",
        headers={"Authorization": f"Bearer {participant_token}"},
    )
    assert skip_response.status_code == 200
    skip_data = skip_response.json()
    assert skip_data["skip_count"] == 1
    assert skip_data["auto_validated"] is False  # Threshold is 2, so not auto-validated yet

    # Get validation list again - skipped image should be gone
    list_response2 = client.get(
        f"/api/v1/competitions/{competition_id}/validations/list",
        headers={"Authorization": f"Bearer {participant_token}"},
    )
    assert list_response2.status_code == 200
    updated_list = list_response2.json()["image_ids"]
    # After skipping one instance of the image, it's removed from DB, so all instances disappear
    assert skip_target not in updated_list, "Skipped image should be removed from queue"


def test_skip_image_auto_validates_at_threshold(client, db_session):
    """Test that after N skips, the image is auto-validated with original label."""
    # Setup: Create host, competitor, images
    host_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "skip-auto-host@example.com",
            "password": "Secure1234",
            "full_name": "Skip Auto Host",
        },
    )
    assert host_signup.status_code == 200
    host_token = host_signup.json()["access_token"]
    host_id = host_signup.json()["user"]["id"]

    # Create 2 competitors to do skips
    comp1_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "skip-auto-comp1@example.com",
            "password": "Secure1234",
            "full_name": "Skip Auto Comp1",
        },
    )
    assert comp1_signup.status_code == 200
    comp1_token = comp1_signup.json()["access_token"]

    comp2_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "skip-auto-comp2@example.com",
            "password": "Secure1234",
            "full_name": "Skip Auto Comp2",
        },
    )
    assert comp2_signup.status_code == 200
    comp2_token = comp2_signup.json()["access_token"]
    comp2_id = comp2_signup.json()["user"]["id"]

    competition_response = client.post(
        "/api/v1/competitions",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Skip Auto Validation Competition", "description": "Test"},
    )
    assert competition_response.status_code == 200
    competition_id = UUID(competition_response.json()["id"])

    # Set validation threshold to 2
    config = db_session.query(Config).filter(Config.competition_id == competition_id).first()
    if config is None:
        config = Config(competition_id=competition_id, max_validations=2)
        db_session.add(config)
    else:
        config.max_validations = 2
    db_session.commit()

    # Create teams
    team1_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={
            "name": "Skip Auto Team 1",
            "user_emails": {"skip-auto-comp1@example.com": 0},
        },
    )
    assert team1_response.status_code == 200
    team1_id = UUID(team1_response.json()["id"])

    team2_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={
            "name": "Skip Auto Team 2",
            "user_emails": {"skip-auto-comp2@example.com": 0},
        },
    )
    assert team2_response.status_code == 200
    team2_id = UUID(team2_response.json()["id"])

    # Create image
    image = _create_image(db_session, str(team1_id), host_id, "skip-auto-test")
    _create_label(db_session, image.id, "original_label")
    target_image_id = image.id

    # Generate assignments (both teams will get the image to validate)
    gen_response = client.post(
        f"/api/v1/competitions/{competition_id}/validations/generate",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert gen_response.status_code == 200

    # First skip from comp1
    skip1 = client.post(
        f"/api/v1/images/{target_image_id}/validations/skip",
        headers={"Authorization": f"Bearer {comp1_token}"},
    )
    assert skip1.status_code == 200
    assert skip1.json()["skip_count"] == 1
    assert skip1.json()["auto_validated"] is False

    # Check image is not yet validated
    label_entry = db_session.query(Label).filter(Label.image_id == target_image_id).first()
    assert label_entry.validated is False

    # Second skip from comp2 (reaches threshold)
    skip2 = client.post(
        f"/api/v1/images/{target_image_id}/validations/skip",
        headers={"Authorization": f"Bearer {comp2_token}"},
    )
    assert skip2.status_code == 200
    assert skip2.json()["skip_count"] == 2
    assert skip2.json()["auto_validated"] is True

    # Check image is now validated with original label
    db_session.refresh(label_entry)
    assert label_entry.validated is True
    assert label_entry.label == "original_label"


def test_skip_image_not_in_queue_returns_error(client, db_session):
    """Test that skipping an image not in the participant's queue returns an error."""
    host_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "skip-error-host@example.com",
            "password": "Secure1234",
            "full_name": "Skip Error Host",
        },
    )
    assert host_signup.status_code == 200
    host_token = host_signup.json()["access_token"]
    host_id = host_signup.json()["user"]["id"]

    other_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "skip-error-other@example.com",
            "password": "Secure1234",
            "full_name": "Skip Error Other",
        },
    )
    assert other_signup.status_code == 200
    other_token = other_signup.json()["access_token"]
    other_id = other_signup.json()["user"]["id"]

    participant_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "skip-error-participant@example.com",
            "password": "Secure1234",
            "full_name": "Skip Error Participant",
        },
    )
    assert participant_signup.status_code == 200
    participant_token = participant_signup.json()["access_token"]

    competition_response = client.post(
        "/api/v1/competitions",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Skip Error Competition", "description": "Test"},
    )
    assert competition_response.status_code == 200
    competition_id = UUID(competition_response.json()["id"])

    # Create team with host and participant
    team_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={
            "name": "Skip Error Team",
            "user_emails": {
                "skip-error-host@example.com": 0,
                "skip-error-participant@example.com": 0,
            },
        },
    )
    assert team_response.status_code == 200
    team_id = UUID(team_response.json()["id"])

    # Create image in other team
    other_team_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={
            "name": "Skip Error Other Team",
            "user_emails": {"skip-error-other@example.com": 0},
        },
    )
    assert other_team_response.status_code == 200
    other_team_id = UUID(other_team_response.json()["id"])

    other_image = _create_image(db_session, str(other_team_id), other_id, "skip-error-other")
    _create_label(db_session, other_image.id, "dog")

    # Try to skip image that's not in participant's queue
    skip_response = client.post(
        f"/api/v1/images/{other_image.id}/validations/skip",
        headers={"Authorization": f"Bearer {participant_token}"},
    )
    assert skip_response.status_code == 400
    assert "not in your validation queue" in skip_response.json()["detail"]


def test_vote_plus_skip_reaches_threshold_and_finalizes(client, db_session):
    """Test mixed interactions: one vote + one skip reaches threshold and finalizes."""
    host_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "mix-host@example.com",
            "password": "Secure1234",
            "full_name": "Mix Host",
        },
    )
    assert host_signup.status_code == 200
    host_token = host_signup.json()["access_token"]
    host_id = host_signup.json()["user"]["id"]

    voter_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "mix-voter@example.com",
            "password": "Secure1234",
            "full_name": "Mix Voter",
        },
    )
    assert voter_signup.status_code == 200
    voter_token = voter_signup.json()["access_token"]

    skipper_signup = client.post(
        "/api/v1/register/signup",
        json={
            "email": "mix-skipper@example.com",
            "password": "Secure1234",
            "full_name": "Mix Skipper",
        },
    )
    assert skipper_signup.status_code == 200
    skipper_token = skipper_signup.json()["access_token"]

    competition_response = client.post(
        "/api/v1/competitions",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Mixed Vote Skip Competition", "description": "Test"},
    )
    assert competition_response.status_code == 200
    competition_id = UUID(competition_response.json()["id"])

    config = db_session.query(Config).filter(Config.competition_id == competition_id).first()
    if config is None:
        config = Config(competition_id=competition_id, max_validations=2)
        db_session.add(config)
    else:
        config.max_validations = 2
    db_session.commit()

    team1_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={
            "name": "Mixed Team 1",
            "user_emails": {"mix-voter@example.com": 0},
        },
    )
    assert team1_response.status_code == 200
    team1_id = UUID(team1_response.json()["id"])

    team2_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={
            "name": "Mixed Team 2",
            "user_emails": {"mix-skipper@example.com": 0},
        },
    )
    assert team2_response.status_code == 200

    image = _create_image(db_session, str(team1_id), host_id, "mixed-vote-skip")
    _create_label(db_session, image.id, "original_label")
    target_image_id = image.id

    generate_response = client.post(
        f"/api/v1/competitions/{competition_id}/validations/generate",
        headers={"Authorization": f"Bearer {host_token}"},
    )
    assert generate_response.status_code == 200

    vote_response = client.post(
        f"/api/v1/images/{target_image_id}/validations",
        headers={"Authorization": f"Bearer {voter_token}"},
        json={"label": "cat"},
    )
    assert vote_response.status_code == 200
    assert vote_response.json()["label"] == "cat"

    interim_label = db_session.query(Label).filter(Label.image_id == target_image_id).first()
    assert interim_label is not None
    assert interim_label.validated is False

    skip_response = client.post(
        f"/api/v1/images/{target_image_id}/validations/skip",
        headers={"Authorization": f"Bearer {skipper_token}"},
    )
    assert skip_response.status_code == 200
    assert skip_response.json()["skip_count"] == 1
    assert skip_response.json()["auto_validated"] is True

    db_session.refresh(interim_label)
    assert interim_label.validated is True
    assert interim_label.label == "cat"


def test_filter_unvalidated_images(db_session):
    """Test that filter_unvalidated_images correctly filters out validated images."""
    from app.services.validation.repository import ValidationRepository

    competition = Competition(name="Filter Test", description="Test")
    db_session.add(competition)
    db_session.commit()
    db_session.refresh(competition)

    team = Team(name="Filter Team", comp_id=competition.id, user_emails={"filter@test.com": 0})
    db_session.add(team)
    db_session.commit()
    db_session.refresh(team)

    # Create 5 images, validate 2, keep 3 unvalidated
    image_ids = []
    for idx in range(5):
        image = Image(
            team_id=team.id,
            author_id=uuid4(),
            filepath=f"/tmp/filter-{idx}.jpg",
            image_hash=f"filter-hash-{idx}",
        )
        db_session.add(image)
        db_session.commit()
        db_session.refresh(image)
        image_ids.append(image.id)

        label = Label(image_id=image.id, label="test", validated=(idx < 2))  # First 2 are validated
        db_session.add(label)
        db_session.commit()

    repository = ValidationRepository(db_session)
    filtered = repository.filter_unvalidated_images(image_ids)

    assert len(filtered) == 3, "Should have 3 unvalidated images"
    assert set(filtered) == set(image_ids[2:]), "Should only include unvalidated images"


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
