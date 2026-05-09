from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, AuthorizationError, NotFoundError, ValidationError
from app.models import RoleType
from app.schemas.label import LabelCreate, LabelResponse, LabelUpdate, LabelValidationResponse
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

from .repository import LabelRepository
from .service import LabelService

router = APIRouter(prefix="/images/{image_id}/labels", tags=["label"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_label_service(db: Session = Depends(get_db)) -> LabelService:
    return LabelService(LabelRepository(db))


@router.post("", response_model=LabelResponse)
async def create_label(
    image_id: UUID,
    payload: LabelCreate,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    label_service: LabelService = Depends(get_label_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        return label_service.create_label(image_id, payload.label)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("", response_model=LabelResponse)
async def get_label(
    image_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    label_service: LabelService = Depends(get_label_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        return label_service.get_label(image_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.put("", response_model=LabelResponse)
async def update_label(
    image_id: UUID,
    payload: LabelUpdate,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    label_service: LabelService = Depends(get_label_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        return label_service.update_label(image_id, payload.label)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post("/validate", response_model=LabelValidationResponse)
async def validate_label(
    image_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    label_service: LabelService = Depends(get_label_service),
):
    try:
        token = extract_bearer_token(authorization)
        competition_id = label_service.get_competition_id(image_id)
        auth_service.require_roles(token, competition_id, {RoleType.host, RoleType.staff})
        return label_service.validate_label(image_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
