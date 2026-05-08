from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.models import Role, User


class AuthRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_user_by_id(self, user_id: UUID) -> Optional[User]:
        return self.db.query(User).filter(User.id == user_id).first()

    def get_role(self, user_id: UUID, competition_id: UUID) -> Optional[Role]:
        return (
            self.db.query(Role)
            .filter(Role.user_id == user_id, Role.competition_id == competition_id)
            .first()
        )

