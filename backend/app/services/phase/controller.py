from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.auth import extract_bearer_token
from app.core.cache import get_validation_cache
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, AuthorizationError, NotFoundError, ValidationError
from app.models import RoleType
from app.services.label.repository import LabelRepository
from app.services.label.service import LabelService
from app.services.validation.repository import ValidationRepository
from app.services.validation.service import ValidationService
from app.schemas.phase import (
    PhaseAdvanceResponse,
    PhaseDeadlineRequest,
    PhaseHistoryResponse,
    PhaseOverrideRequest,
    PhaseResponse,
    PhaseTimelineResponse,
    PhaseTransitionModeRequest,
    PhaseValidateRequest,
    PhaseValidationResponse,
)
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

from .repository import PhaseRepository
from .service import PhaseService

router = APIRouter(prefix="/competitions/{competition_id}/phase", tags=["phase"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_phase_service(db: Session = Depends(get_db)) -> PhaseService:
    return PhaseService(PhaseRepository(db))


@router.get("", response_model=PhaseResponse)
async def get_current_phase(
    competition_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    phase_service: PhaseService = Depends(get_phase_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        return phase_service.get_current_phase(competition_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.post("/advance", response_model=PhaseAdvanceResponse)
async def advance_phase(
    competition_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    phase_service: PhaseService = Depends(get_phase_service),
    db: Session = Depends(get_db),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.require_roles(token, competition_id, {RoleType.host})
        result = phase_service.advance_phase(competition_id, user.id)

        # Auto-generate validation assignments when entering Data Validation phase
        if result.get("current_phase") == "2":
            try:
                validation_service = ValidationService(
                    ValidationRepository(db, get_validation_cache()),
                    LabelService(LabelRepository(db)),
                )
                validation_service.generate_assignments(competition_id)
            except Exception:
                pass  # non-blocking — generation can be retried manually

        return result
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/decrement", response_model=PhaseAdvanceResponse)
async def decrement_phase(
    competition_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    phase_service: PhaseService = Depends(get_phase_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.require_roles(token, competition_id, {RoleType.host})
        return phase_service.decrement_phase(competition_id, user.id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.put("/override")
async def override_phase(
    competition_id: UUID,
    payload: PhaseOverrideRequest,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    phase_service: PhaseService = Depends(get_phase_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.require_roles(token, competition_id, {RoleType.host})
        return phase_service.override_phase(
            competition_id, payload.target_phase, payload.reason, user.id
        )
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.put("/deadline")
async def adjust_deadline(
    competition_id: UUID,
    payload: PhaseDeadlineRequest,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    phase_service: PhaseService = Depends(get_phase_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.require_roles(token, competition_id, {RoleType.host})
        return phase_service.adjust_phase_deadline(
            competition_id, payload.new_deadline, user.id
        )
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.put("/transition-mode")
async def set_transition_mode(
    competition_id: UUID,
    payload: PhaseTransitionModeRequest,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    phase_service: PhaseService = Depends(get_phase_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.require_roles(token, competition_id, {RoleType.host})
        return phase_service.set_transition_mode(competition_id, payload.mode, user.id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/timeline", response_model=PhaseTimelineResponse)
async def get_timeline(
    competition_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    phase_service: PhaseService = Depends(get_phase_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        phases = phase_service.get_timeline(competition_id)
        return {"phases": phases, "total": len(phases)}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.get("/history", response_model=PhaseHistoryResponse)
async def get_history(
    competition_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    phase_service: PhaseService = Depends(get_phase_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        logs = phase_service.get_history(competition_id)
        return {"audit_logs": logs, "total": len(logs)}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.post("/validate", response_model=PhaseValidationResponse)
async def validate_transition(
    competition_id: UUID,
    payload: PhaseValidateRequest,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    phase_service: PhaseService = Depends(get_phase_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        current = phase_service.get_current_phase(competition_id).current_phase
        return phase_service.validate_phase_transition(current, payload.target_phase)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))

