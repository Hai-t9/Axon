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
        candidates = [value]
        if isinstance(value, UUID):
            candidates.append(str(value))
            return candidates
        if isinstance(value, str):
            try:
                candidates.append(UUID(value))
            except ValueError:
                pass
        return candidates

    def get_user_by_id(self, user_id) -> Optional[User]:
        candidates = self._id_candidates(user_id)
        if not candidates:
            return None
        return self.db.query(User).filter(User.id.in_(candidates)).first()

    def get_role(self, user_id: int, competition_id: int) -> Optional[Role]:
        user_candidates = self._id_candidates(user_id)
        competition_candidates = self._id_candidates(competition_id)
        if not user_candidates or not competition_candidates:
            return None
        return (
            self.db.query(Role)
            .filter(
                Role.user_id.in_(user_candidates),
                Role.competition_id.in_(competition_candidates),
            )
            .first()
        )

