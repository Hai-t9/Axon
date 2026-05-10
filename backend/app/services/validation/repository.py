import time
from typing import Any
from uuid import UUID

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.cache import ValidationCache
from app.models import Config, Image, Label, LabelValidation, Team


VALIDATION_ASSIGNMENT_TTL_SECONDS = 86400
_memory_assignment_store: dict[str, list[str]] = {}
_memory_assignment_expiry: dict[str, float] = {}


def _normalize_uuid(value: Any) -> UUID:
    if isinstance(value, UUID):
        return value
    return UUID(str(value))


def _current_time() -> float:
    return time.time()


class ValidationRepository:
    def __init__(self, db: Session, cache: ValidationCache | None = None):
        self.db = db
        self.cache = cache

    def _redis_client(self):
        if self.cache and getattr(self.cache, "client", None):
            return self.cache.client
        return None

    def _set_assignment_list(self, key: str, values: list[UUID], ttl_seconds: int) -> bool:
        client = self._redis_client()
        string_values = [str(value) for value in values]

        if client:
            client.delete(key)
            if string_values:
                client.rpush(key, *string_values)
            if ttl_seconds > 0:
                client.expire(key, ttl_seconds)
            return True

        _memory_assignment_store[key] = string_values
        if ttl_seconds > 0:
            _memory_assignment_expiry[key] = _current_time() + ttl_seconds
        else:
            _memory_assignment_expiry.pop(key, None)
        return True

    def _get_assignment_list(self, key: str) -> list[UUID]:
        client = self._redis_client()
        if client:
            values = client.lrange(key, 0, -1)
            return [UUID(value) for value in values]

        expires_at = _memory_assignment_expiry.get(key)
        if expires_at is not None and _current_time() >= expires_at:
            _memory_assignment_store.pop(key, None)
            _memory_assignment_expiry.pop(key, None)
            return []

        values = _memory_assignment_store.get(key, [])
        return [UUID(value) for value in values]

    def _assignment_key_for_team(self, team_id: UUID) -> str:
        return f"validation:team:{team_id}"

    def _assignment_key_for_participant(self, participant_id: UUID) -> str:
        return f"validation:participant:{participant_id}"

    def fetch_all_teams(self, comp_id: UUID) -> list[Team]:
        return (
            self.db.query(Team)
            .filter(Team.comp_id == comp_id)
            .order_by(Team.id.asc())
            .all()
        )

    def fetch_all_competition_images(self, comp_id: UUID) -> list[UUID]:
        """Fetch all image IDs in the competition, ordered by image_id."""
        rows = (
            self.db.query(Label.image_id)
            .join(Image, Image.id == Label.image_id)
            .join(Team, Team.id == Image.team_id)
            .filter(Team.comp_id == comp_id)
            .order_by(Label.image_id.asc())
            .all()
        )
        return [row.image_id for row in rows]

    def store_team_assignments(self, team_id: UUID, image_ids: list[UUID]) -> bool:
        return self._set_assignment_list(
            self._assignment_key_for_team(team_id),
            image_ids,
            VALIDATION_ASSIGNMENT_TTL_SECONDS,
        )

    def store_participant_assignments(self, participant_id: UUID, image_ids: list[UUID]) -> bool:
        return self._set_assignment_list(
            self._assignment_key_for_participant(participant_id),
            image_ids,
            VALIDATION_ASSIGNMENT_TTL_SECONDS,
        )

    def get_participant_assignments(self, participant_id: UUID) -> list[UUID]:
        return self._get_assignment_list(self._assignment_key_for_participant(participant_id))

    def get_team_assignments(self, team_id: UUID) -> list[UUID]:
        return self._get_assignment_list(self._assignment_key_for_team(team_id))

    def find_participant_team(self, comp_id: UUID, participant_id: UUID) -> UUID | None:
        # Look up the user's email, then find the team containing that email
        from app.models import User

        user = self.db.query(User).filter(User.id == participant_id).first()
        if not user:
            return None
        user_email = user.email.strip().lower()

        teams = (
            self.db.query(Team)
            .filter(Team.comp_id == comp_id)
            .all()
        )
        for team in teams:
            emails_dict = team.user_emails or {}
            if user_email in {k.lower() for k in emails_dict.keys()}:
                return team.id
        return None

    def find_validation_threshold(self, comp_id: UUID) -> int | None:
        config = (
            self.db.query(Config)
            .filter(Config.competition_id == comp_id)
            .first()
        )
        if not config:
            return None
        return config.max_validations

    def insert_vote(self, image_id: UUID, validator_id: UUID, label: str) -> LabelValidation | None:
        label_entry = self.db.query(Label).filter(Label.image_id == image_id).first()
        if not label_entry or label_entry.validated:
            return None

        existing_vote = (
            self.db.query(LabelValidation)
            .filter(
                LabelValidation.label_id == label_entry.id,
                LabelValidation.validator_id == validator_id,
            )
            .first()
        )
        if existing_vote:
            return None

        vote = LabelValidation(label_id=label_entry.id, validator_id=validator_id, label=label)
        self.db.add(vote)
        self.db.commit()
        self.db.refresh(vote)
        return vote

    def count_votes_for_image(self, image_id: UUID) -> int:
        return int(
            self.db.query(func.count(LabelValidation.id))
            .join(Label, Label.id == LabelValidation.label_id)
            .filter(Label.image_id == image_id)
            .scalar()
            or 0
        )

    def find_label_by_image_id(self, image_id: UUID) -> Label | None:
        return self.db.query(Label).filter(Label.image_id == image_id).first()

    def find_votes_by_label_id(self, label_id: int) -> list[LabelValidation]:
        return (
            self.db.query(LabelValidation)
            .filter(LabelValidation.label_id == label_id)
            .order_by(LabelValidation.id.asc())
            .all()
        )

    def remove_from_team_assignment(self, team_id: UUID, image_id: UUID) -> int:
        """Remove an image_id from a team's validation queue using Redis LREM.
        Returns the number of elements removed."""
        client = self._redis_client()
        key = self._assignment_key_for_team(team_id)
        string_image_id = str(image_id)

        if client:
            return int(client.lrem(key, 0, string_image_id))

        # Fallback to in-memory store
        values = _memory_assignment_store.get(key, [])
        removed = values.count(string_image_id)
        _memory_assignment_store[key] = [v for v in values if v != string_image_id]
        return removed

    def increment_skip_count(self, image_id: UUID) -> int:
        """Increment skip count for an image in Redis. Returns the new count.
        Sets TTL to 24 hours if this is the first increment."""
        client = self._redis_client()
        key = f"validation:skip_count:{image_id}"

        if client:
            count = client.incr(key)
            if count == 1:
                client.expire(key, VALIDATION_ASSIGNMENT_TTL_SECONDS)
            return count

        # Fallback to in-memory store
        current = int(_memory_assignment_store.get(f"count:{key}", 0) or 0)
        current += 1
        _memory_assignment_store[f"count:{key}"] = str(current)
        if current == 1:
            _memory_assignment_expiry[f"count:{key}"] = _current_time() + VALIDATION_ASSIGNMENT_TTL_SECONDS
        return current

    def get_skip_count(self, image_id: UUID) -> int:
        """Get the current skip count for an image."""
        client = self._redis_client()
        key = f"validation:skip_count:{image_id}"
        
        if client:
            return int(client.get(key) or 0)
            
        return int(_memory_assignment_store.get(f"count:{key}", 0) or 0)

    def filter_unvalidated_images(self, image_ids: list[UUID]) -> list[UUID]:
        """Filter a list of image IDs to only include those not yet validated.
        Returns image_ids where validated == False."""
        if not image_ids:
            return []

        validated_ids = set(
            row[0]
            for row in self.db.query(Label.image_id)
            .filter(Label.image_id.in_(image_ids), Label.validated.is_(True))
            .all()
        )
        return [img_id for img_id in image_ids if img_id not in validated_ids]

    def fetch_image_details(self, image_ids: list[UUID]) -> dict[UUID, dict]:
        rows = (
            self.db.query(Label.image_id, Image.filepath, Label.label)
            .join(Label, Label.image_id == Image.id)
            .filter(Label.image_id.in_(image_ids))
            .all()
        )
        return {
            row.image_id: {"filepath": row.filepath, "label": row.label}
            for row in rows
        }

    def find_pending_by_comp(self, comp_id: UUID) -> list[dict]:
        rows = (
            self.db.query(Label.image_id, Image.filepath, Label.label)
            .join(Image, Image.id == Label.image_id)
            .join(Team, Team.id == Image.team_id)
            .filter(Team.comp_id == comp_id, Label.validated.is_(False))
            .order_by(Label.image_id.asc())
            .all()
        )
        return [
            {"id": row.image_id, "filepath": row.filepath, "label": row.label}
            for row in rows
        ]
