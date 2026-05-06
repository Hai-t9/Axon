"""
FILE: backend/app/services/invitation/controller.py
"""

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, AuthorizationError, NotFoundError
from app.models import RoleType
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

from .service import InvitationService

router = APIRouter(prefix="/invitations", tags=["invitation"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


@router.post(
    "/competitions/{comp_id}/generate",
    summary="Generate an invitation link for a competition",
)
async def generate_link(
    comp_id: int,
    request: Request,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    """
    Generate a time-limited invitation link.
    **Host only.**
    """
    try:
        token = extract_bearer_token(authorization)
        auth_service.require_roles(token, comp_id, {RoleType.host})

        base_url = str(request.base_url)
        service = InvitationService(db)
        link = service.create_invitation_link(comp_id, base_url)
        return {"invitation_link": link, "competition_id": comp_id}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post(
    "/join",
    summary="Join a competition via invitation token",
)
async def join_competition(
    token: str = Query(..., description="Invitation token from the link"),
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    """
    Accept a competition invitation.
    The caller must be authenticated. They will receive the *participant* role.
    """
    try:
        jwt_token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(jwt_token)

        service = InvitationService(db)
        return service.join_via_token(token, user)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))