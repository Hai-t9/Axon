from typing import Iterable

from app.core.auth import verify_access_token
from app.core.exceptions import AuthenticationError, AuthorizationError
from app.models import RoleType, User

from .repository import AuthRepository


class AuthService:
    def __init__(self, repository: AuthRepository):
        self.repository = repository

    def get_current_user(self, token: str) -> User:
        user_id = verify_access_token(token)
        if not user_id:
            raise AuthenticationError("Invalid or expired token")

        user = self.repository.get_user_by_id(user_id)
        if not user:
            raise AuthenticationError("User not found")

        return user

    def require_roles(
        self, token: str, competition_id: int, allowed_roles: Iterable[RoleType]
    ) -> User:
        user = self.get_current_user(token)
        role = self.repository.get_role(user.id, competition_id)
        if not role or role.role not in set(allowed_roles):
            raise AuthorizationError("Insufficient permissions")

        return user

