"""
FILE: backend/app/services/evaluation/controller.py
"""

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import (
    AuthenticationError,
    AuthorizationError,
    NotFoundError,
    ValidationError,
)
from app.models import RoleType
from app.schemas.evaluation import (
    EvaluationJobResponse,
    EvaluationResultResponse,
    EvaluationScheduleRequest,
)
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

from .repository import EvaluationRepository
from .service import EvaluationService

router = APIRouter(tags=["evaluation"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_evaluation_service(db: Session = Depends(get_db)) -> EvaluationService:
    return EvaluationService(EvaluationRepository(db))


# -----------------------------------------------------------------------
# POST /models/{model_id}/evaluate
#   Schedule (or run inline) a model evaluation.
#   Host/staff only.
# -----------------------------------------------------------------------
@router.post(
    "/models/{model_id}/evaluate",
    response_model=EvaluationJobResponse,
    summary="Schedule a model for evaluation",
)
async def schedule_evaluation(
    model_id: int,
    payload: EvaluationScheduleRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    """
    Trigger evaluation for a submitted model.

    **Protocol options:**
    - `standard` — 80/20 random train/test split
    - `loto` — Leave-One-Team-Out: test on submitting team, train on rest
    - `toto` — Train-On-One-Team-Only: train on submitting team, test on rest

    **Phase restriction:** competition must be in *evaluation* phase.
    """
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)

        # Fetch model to get competition_id for role check.
        service = EvaluationService(EvaluationRepository(db))
        model = service.repository.find_model(model_id)
        if not model:
            raise NotFoundError(f"Model {model_id} not found")

        auth_service.require_roles(
            token, model.competition_id, {RoleType.host, RoleType.staff}
        )

        result = service.schedule_evaluation(
            model_id=model_id,
            protocol=payload.protocol,
            db=db,
        )
        return result
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


# -----------------------------------------------------------------------
# GET /models/{model_id}/evaluation
#   Retrieve evaluation result for a model.
# -----------------------------------------------------------------------
@router.get(
    "/models/{model_id}/evaluation",
    response_model=EvaluationResultResponse,
    summary="Get evaluation result for a model",
)
async def get_evaluation(
    model_id: int,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        service = EvaluationService(EvaluationRepository(db))
        return service.get_evaluation(model_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


# -----------------------------------------------------------------------
# POST /evaluations/{model_id}/result   (internal — called by Celery worker)
#   Store / update an evaluation result.
# -----------------------------------------------------------------------
@router.post(
    "/evaluations/{model_id}/result",
    response_model=EvaluationResultResponse,
    summary="[Internal] Store evaluation result from worker",
    include_in_schema=False,  # Hide from public Swagger docs.
)
async def store_result(
    model_id: int,
    score: float,
    worker_secret: str = Header(..., alias="X-Worker-Secret"),
    db: Session = Depends(get_db),
):
    """
    Internal endpoint called by evaluation workers to persist scores.
    Protected by a shared secret rather than JWT.
    """
    import os

    expected = os.getenv("WORKER_SECRET", "dev-worker-secret")
    if worker_secret != expected:
        raise HTTPException(status_code=403, detail="Invalid worker secret")

    service = EvaluationService(EvaluationRepository(db))
    try:
        return service.store_result(model_id, score)
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))