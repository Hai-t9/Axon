from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, NotFoundError, ValidationError
from app.schemas.validation import (
    ValidationBatchResponse,
    ValidationPendingResponse,
    ValidationVoteCreate,
    ValidationVoteResponse,
)
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService
from app.services.label.repository import LabelRepository
from app.services.label.service import LabelService

from .repository import ValidationRepository
from .service import ValidationService

router = APIRouter(tags=["validation"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_validation_service(db: Session = Depends(get_db)) -> ValidationService:
    repository = ValidationRepository(db)
    label_service = LabelService(LabelRepository(db))
    return ValidationService(repository, label_service)


@router.get("/competitions/{comp_id}/validations/batch", response_model=ValidationBatchResponse)
async def get_validation_batch(
    comp_id: int,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    validation_service: ValidationService = Depends(get_validation_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        return validation_service.get_validation_batch(comp_id, user.id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post("/images/{image_id}/validations", response_model=ValidationVoteResponse)
async def submit_vote(
    image_id: int,
    payload: ValidationVoteCreate,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    validation_service: ValidationService = Depends(get_validation_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        return validation_service.submit_vote(image_id, user.id, payload.label)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/competitions/{comp_id}/validations/pending", response_model=ValidationPendingResponse)
async def get_pending_validations(
    comp_id: int,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    validation_service: ValidationService = Depends(get_validation_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        return validation_service.get_pending_validations(comp_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
