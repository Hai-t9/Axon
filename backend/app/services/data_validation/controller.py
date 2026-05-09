from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, NotFoundError, ValidationError
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

from .repository import DataValidationRepository
from .service import DataValidationService

router = APIRouter(prefix="/competitions/{comp_id}/data-validation", tags=["data-validation"])


class CorrectLabelRequest(BaseModel):
    label: str


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_validation_service(db: Session = Depends(get_db)) -> DataValidationService:
    return DataValidationService(DataValidationRepository(db))


@router.get("/queue")
async def get_validation_queue(
    comp_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    validation_service: DataValidationService = Depends(get_validation_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        return validation_service.get_queue(comp_id, user.id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post("/images/{image_id}/validate")
async def validate_image(
    comp_id: UUID,
    image_id: int,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    validation_service: DataValidationService = Depends(get_validation_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        return validation_service.validate(image_id, user.id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/images/{image_id}/skip")
async def skip_image(
    comp_id: UUID,
    image_id: int,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    validation_service: DataValidationService = Depends(get_validation_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        return validation_service.skip(image_id, user.id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post("/images/{image_id}/correct")
async def correct_label(
    comp_id: UUID,
    image_id: int,
    payload: CorrectLabelRequest,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    validation_service: DataValidationService = Depends(get_validation_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        return validation_service.correct(image_id, payload.label, user.id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/progress")
async def get_validation_progress(
    comp_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    validation_service: DataValidationService = Depends(get_validation_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        return validation_service.get_progress(comp_id, user.id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
