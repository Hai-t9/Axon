from typing import Optional

from sqlalchemy.orm import Session

from app.models import Role, User


class AuthRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_user_by_id(self, user_id: int) -> Optional[User]:
        return self.db.query(User).filter(User.id == user_id).first()

    def get_role(self, user_id: int, competition_id: int) -> Optional[Role]:
        return (
            self.db.query(Role)
            .filter(Role.user_id == user_id, Role.competition_id == competition_id)
            .first()
        )

