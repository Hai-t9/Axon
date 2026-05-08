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

    def _set_assignment_list(self, key: str, values: list[int], ttl_seconds: int) -> bool:
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

    def _get_assignment_list(self, key: str) -> list[int]:
        client = self._redis_client()
        if client:
            values = client.lrange(key, 0, -1)
            return [int(value) for value in values]

        expires_at = _memory_assignment_expiry.get(key)
        if expires_at is not None and _current_time() >= expires_at:
            _memory_assignment_store.pop(key, None)
            _memory_assignment_expiry.pop(key, None)
            return []

        values = _memory_assignment_store.get(key, [])
        return [int(value) for value in values]

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

    def count_team_images(self, comp_id: UUID, team_id: UUID) -> int:
        return int(
            self.db.query(func.count(Image.id))
            .join(Team, Team.id == Image.team_id)
            .filter(Team.comp_id == comp_id, Image.team_id == team_id)
            .scalar()
            or 0
        )

    def fetch_available_own_images(
        self,
        comp_id: UUID,
        team_id: UUID,
        assigned_counts: dict[int, int],
        threshold: int,
    ) -> int:
        rows = (
            self.db.query(Image.id)
            .join(Label, Label.image_id == Image.id)
            .join(Team, Team.id == Image.team_id)
            .filter(
                Team.comp_id == comp_id,
                Image.team_id == team_id,
                Label.validated.is_(False),
            )
            .order_by(Image.id.asc())
            .all()
        )
        return sum(1 for row in rows if assigned_counts.get(int(row.id), 0) < threshold)

    def fetch_own_images(
        self,
        comp_id: UUID,
        team_id: UUID,
        own_quota: int,
        assigned_counts: dict[int, int],
        threshold: int,
    ) -> list[int]:
        rows = (
            self.db.query(Image.id)
            .join(Label, Label.image_id == Image.id)
            .join(Team, Team.id == Image.team_id)
            .filter(
                Team.comp_id == comp_id,
                Image.team_id == team_id,
                Label.validated.is_(False),
            )
            .order_by(Image.id.asc())
            .all()
        )
        return self._pick_images([int(row.id) for row in rows], own_quota, assigned_counts, threshold)

    def fetch_other_images(
        self,
        comp_id: UUID,
        team_id: UUID,
        other_quota: int,
        assigned_counts: dict[int, int],
        threshold: int,
    ) -> list[int]:
        rows = (
            self.db.query(Image.id)
            .join(Label, Label.image_id == Image.id)
            .join(Team, Team.id == Image.team_id)
            .filter(
                Team.comp_id == comp_id,
                Image.team_id != team_id,
                Label.validated.is_(False),
            )
            .order_by(Image.id.asc())
            .all()
        )
        return self._pick_images([int(row.id) for row in rows], other_quota, assigned_counts, threshold)

    def _pick_images(
        self,
        image_ids: list[int],
        quota: int,
        assigned_counts: dict[int, int],
        threshold: int,
    ) -> list[int]:
        picked: list[int] = []
        for image_id in image_ids:
            if len(picked) >= quota:
                break
            if assigned_counts.get(image_id, 0) >= threshold:
                continue
            picked.append(image_id)
            assigned_counts[image_id] = assigned_counts.get(image_id, 0) + 1
        return picked

    def fetch_participants_by_team(self, team_id: UUID) -> list[UUID]:
        team = self.db.query(Team).filter(Team.id == team_id).first()
        if not team or not team.user_ids:
            return []

        participants: list[UUID] = []
        for raw_user_id in team.user_ids:
            try:
                participants.append(_normalize_uuid(raw_user_id))
            except (TypeError, ValueError):
                continue
        return participants

    def store_team_assignments(self, team_id: UUID, image_ids: list[int]) -> bool:
        return self._set_assignment_list(
            self._assignment_key_for_team(team_id),
            image_ids,
            VALIDATION_ASSIGNMENT_TTL_SECONDS,
        )

    def store_participant_assignments(self, participant_id: UUID, image_ids: list[int]) -> bool:
        return self._set_assignment_list(
            self._assignment_key_for_participant(participant_id),
            image_ids,
            VALIDATION_ASSIGNMENT_TTL_SECONDS,
        )

    def get_participant_assignments(self, participant_id: UUID) -> list[int]:
        return self._get_assignment_list(self._assignment_key_for_participant(participant_id))

    def get_team_assignments(self, team_id: UUID) -> list[int]:
        return self._get_assignment_list(self._assignment_key_for_team(team_id))

    def find_participant_team(self, comp_id: UUID, participant_id: UUID) -> UUID | None:
        # Simple in-Python lookup: iterate teams in competition and match user_ids.
        teams = (
            self.db.query(Team)
            .filter(Team.comp_id == comp_id)
            .all()
        )
        for team in teams:
            if not team or not team.user_ids:
                continue
            for raw_user_id in team.user_ids:
                try:
                    if _normalize_uuid(raw_user_id) == _normalize_uuid(participant_id):
                        return team.id
                except (TypeError, ValueError):
                    continue
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

    def insert_vote(self, image_id: int, validator_id: UUID, label: str) -> LabelValidation | None:
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

    def count_votes_for_image(self, image_id: int) -> int:
        return int(
            self.db.query(func.count(LabelValidation.id))
            .join(Label, Label.id == LabelValidation.label_id)
            .filter(Label.image_id == image_id)
            .scalar()
            or 0
        )

    def find_label_by_image_id(self, image_id: int) -> Label | None:
        return self.db.query(Label).filter(Label.image_id == image_id).first()

    def find_votes_by_label_id(self, label_id: int) -> list[LabelValidation]:
        return (
            self.db.query(LabelValidation)
            .filter(LabelValidation.label_id == label_id)
            .order_by(LabelValidation.id.asc())
            .all()
        )

    def find_pending_by_comp(self, comp_id: UUID) -> list[dict]:
        rows = (
            self.db.query(Image.id, Image.filepath, Label.label)
            .join(Label, Label.image_id == Image.id)
            .join(Team, Team.id == Image.team_id)
            .filter(Team.comp_id == comp_id, Label.validated.is_(False))
            .order_by(Image.id.asc())
            .all()
        )
        return [
            {"id": row.id, "filepath": row.filepath, "label": row.label}
            for row in rows
        ]
