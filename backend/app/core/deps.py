from uuid import UUID

from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, AuthorizationError
from app.models import RoleType, User
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_current_user(
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
) -> User:
    try:
        token = extract_bearer_token(authorization)
        return auth_service.get_current_user(token)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


def require_roles(allowed_roles: set[RoleType]):
    def dependency(
        comp_id: str,
        authorization: str = Header(...),
        auth_service: AuthService = Depends(get_auth_service),
    ) -> User:
        try:
            token = extract_bearer_token(authorization)
            return auth_service.require_roles(token, UUID(comp_id), allowed_roles)
        except AuthenticationError as exc:
            raise HTTPException(status_code=401, detail=str(exc))
        except AuthorizationError as exc:
            raise HTTPException(status_code=403, detail=str(exc))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid UUID format.")

    return dependency
