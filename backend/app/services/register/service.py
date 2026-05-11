from app.core.auth import create_access_token
from app.core.exceptions import AuthenticationError, ValidationError
from app.core.security import hash_password, verify_password
from app.schemas.user import LoginRequest, SignupRequest

from .repository import RegisterRepository


class RegisterService:
    def __init__(self, repository: RegisterRepository):
        self.repository = repository

    def signup(self, payload: SignupRequest) -> dict:
        if self.repository.get_by_email(payload.email):
            raise ValidationError("Email already registered")

        full_name = payload.full_name or payload.email.split("@", 1)[0]
        user = self.repository.create(
            {
                "email": payload.email,
                "password": hash_password(payload.password),
                "fullname": full_name,
            }
        )
        token = create_access_token(user.id)

        return {
            "access_token": token,
            "token_type": "bearer",
            "user": user,
        }

    def login(self, payload: LoginRequest) -> dict:
        user = self.repository.get_by_email(payload.email)
        if not user or not verify_password(payload.password, user.password):
            raise AuthenticationError("Invalid email or password")

        token = create_access_token(user.id)
        return {
            "access_token": token,
            "token_type": "bearer",
            "user": user,
        }

