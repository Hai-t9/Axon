from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.models import User


class RegisterRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_email(self, email: str) -> Optional[User]:
        return self.db.query(User).filter(User.email == email).first()

    def create(self, user_data: dict) -> User:
        user = User(**user_data)
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def mark_verified(self, user_id: UUID) -> None:
        user = self.db.query(User).filter(User.id == user_id).first()
        if user:
            user.email_verified = True
            self.db.commit()

