import os
import sys
from pathlib import Path
from uuid import UUID

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
from app.models import Image
from app.services.competition.controller import get_db as competition_get_db
from app.services.label.controller import get_db as label_get_db
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
    app.dependency_overrides[label_get_db] = override_get_db

    with TestClient(app) as client:
        yield client

    app.dependency_overrides.clear()


def _to_uuid(value) -> UUID:
    if isinstance(value, UUID):
        return value
    return UUID(str(value))


def _create_image(db_session, team_id, author_id, comp_id=None, label=None) -> Image:
    team_uuid = _to_uuid(team_id)
    author_uuid = _to_uuid(author_id)
    filename = f"img_{team_uuid}_{author_uuid}.jpg"

    if comp_id is not None:
        safe_label = label.replace(" ", "_").lower() if label else "unlabeled"
        filepath = f"uploads/{comp_id}/images/{team_uuid}/{safe_label}/{filename}"
    else:
        filepath = f"uploads/images/{filename}"

    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    Path(filepath).touch()

    image = Image(
        team_id=team_uuid,
        author_id=author_uuid,
        filepath=filepath,
        image_hash=f"hash_{team_uuid}_{author_uuid}",
    )
    db_session.add(image)
    db_session.commit()
    db_session.refresh(image)
    return image


def test_label_flow_create_get_update_validate(client, db_session):
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
        json={"name": "Label Test Competition", "description": "Test"},
    )
    assert competition_response.status_code == 200
    competition_id = competition_response.json()["id"]

    team_response = client.post(
        f"/api/v1/competitions/{competition_id}/teams",
        headers={"Authorization": f"Bearer {host_token}"},
        json={"name": "Label Test Team", "user_emails": {"host@example.com": 0}},
    )
    assert team_response.status_code == 200
    team_id = team_response.json()["id"]

    old_filepath, new_filepath = None, None
    try:
        image = _create_image(db_session, team_id=team_id, author_id=host_id,
                               comp_id=competition_id, label="cat")
        old_filepath = image.filepath

        create_response = client.post(
            f"/api/v1/images/{image.id}/labels",
            headers={"Authorization": f"Bearer {host_token}"},
            json={"label": "cat"},
        )
        assert create_response.status_code == 200
        assert create_response.json()["label"] == "cat"
        assert create_response.json()["validated"] is False

        get_response = client.get(
            f"/api/v1/images/{image.id}/labels",
            headers={"Authorization": f"Bearer {host_token}"},
        )
        assert get_response.status_code == 200
        assert get_response.json()["label"] == "cat"

        update_response = client.put(
            f"/api/v1/images/{image.id}/labels",
            headers={"Authorization": f"Bearer {host_token}"},
            json={"label": "dog"},
        )
        assert update_response.status_code == 200
        assert update_response.json()["label"] == "dog"

        # Refresh image from DB to get updated filepath
        db_session.refresh(image)
        new_filepath = image.filepath

        # Verify old file was moved to new location
        assert not os.path.exists(old_filepath), f"Old file should not exist: {old_filepath}"
        assert os.path.exists(new_filepath), f"New file should exist: {new_filepath}"
        assert "dog" in new_filepath

        validate_response = client.post(
            f"/api/v1/images/{image.id}/labels/validate",
            headers={"Authorization": f"Bearer {host_token}"},
        )
        assert validate_response.status_code == 200
        assert validate_response.json()["validated"] is True
    finally:
        for p in (old_filepath, new_filepath):
            if p and os.path.exists(p):
                os.remove(p)
                try:
                    os.removedirs(os.path.dirname(p))
                except OSError:
                    pass


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
