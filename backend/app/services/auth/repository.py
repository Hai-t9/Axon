from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.models import Role, User


class AuthRepository:
    def __init__(self, db: Session):
        self.db = db

    def _id_candidates(self, value) -> list:
        if value is None:
            return []
        # Normalize inputs into a list of UUID or primitive candidates.
        # If a mapping/dict is provided, try common id keys.
        if isinstance(value, dict):
            for key in ("id", "user_id", "sub"):
                if key in value:
                    return self._id_candidates(value[key])
            return []

        # If already a UUID, return it only.
        if isinstance(value, UUID):
            return [value]

        # If it's a string, try to parse as UUID first.
        if isinstance(value, str):
            try:
                return [UUID(value)]
            except (ValueError, TypeError):
                # fallback to returning the raw string (e.g., numeric ids)
                return [value]

        # For ints or other scalar types, return as-is in a list.
        return [value]

    def get_user_by_id(self, user_id) -> Optional[User]:
        candidates = self._id_candidates(user_id)
        if not candidates:
            return None

        # Normalize candidates: prefer UUID objects where possible to avoid SQLAlchemy bind issues
        processed = []
        for c in candidates:
            if isinstance(c, UUID):
                processed.append(c)
            elif isinstance(c, str):
                try:
                    processed.append(UUID(c))
                except (ValueError, TypeError):
                    processed.append(c)
            elif isinstance(c, dict):
                processed.extend(self._id_candidates(c))
            else:
                processed.append(c)

        if not processed:
            return None
        return self.db.query(User).filter(User.id.in_(processed)).first()

    def get_role(self, user_id: int, competition_id: int) -> Optional[Role]:
        user_candidates = self._id_candidates(user_id)
        competition_candidates = self._id_candidates(competition_id)
        if not user_candidates or not competition_candidates:
            return None

        # Normalize candidates similarly to get_user_by_id to prefer UUIDs
        def _normalize_list(items):
            out = []
            for c in items:
                if isinstance(c, UUID):
                    out.append(c)
                elif isinstance(c, str):
                    try:
                        out.append(UUID(c))
                    except (ValueError, TypeError):
                        out.append(c)
                elif isinstance(c, dict):
                    out.extend(self._id_candidates(c))
                else:
                    out.append(c)
            return out

        user_proc = _normalize_list(user_candidates)
        comp_proc = _normalize_list(competition_candidates)

        return (
            self.db.query(Role)
            .filter(
                Role.user_id.in_(user_proc),
                Role.competition_id.in_(comp_proc),
            )
            .first()
        )

