import logging
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy.orm import Session

logger = logging.getLogger("evaluation_orchestration.controller")

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import (
    AuthenticationError,
    AuthorizationError,
    NotFoundError,
    ValidationError,
)
from app.models import RoleType
from app.schemas.evaluation_orchestration import (
    CompetitionEvaluationsResponse,
    CompetitionResultsResponse,
    EvaluationJobResponse,
    EvaluationResultsResponse,
    EvaluationStatusResponse,
    RetryEvaluationResponse,
    ScheduleEvaluationRequest,
)
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

from .repository import EvaluationOrchestrationRepository
from .service import EvaluationOrchestrationService

router = APIRouter(tags=["evaluation_orchestration"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_eval_service(db: Session = Depends(get_db)) -> EvaluationOrchestrationService:
    return EvaluationOrchestrationService(EvaluationOrchestrationRepository(db))


@router.post(
    "/competitions/{comp_id}/models/{model_id}/evaluate",
    response_model=EvaluationJobResponse,
    summary="Schedule a model for evaluation (host/staff only)",
)
async def schedule_evaluation(
    comp_id: str,
    model_id: str,
    body: ScheduleEvaluationRequest,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    eval_service: EvaluationOrchestrationService = Depends(get_eval_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        auth_service.require_roles(token, UUID(comp_id), {RoleType.host, RoleType.staff})
        result = eval_service.scheduleEvaluation(
            UUID(model_id),
            body.protocol,
            body.folds,
        )
        return EvaluationJobResponse(**result)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except ValueError:
        logger.exception("schedule_evaluation failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid UUID format.")


@router.get(
    "/competitions/{comp_id}/models/{model_id}/evaluate/status",
    response_model=EvaluationStatusResponse,
    summary="Get evaluation status for a model (by model ID within competition)",
)
async def get_model_evaluation_status(
    comp_id: str,
    model_id: str,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    eval_service: EvaluationOrchestrationService = Depends(get_eval_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        result = eval_service.getEvaluationStatusByModel(UUID(model_id))
        return EvaluationStatusResponse(**result)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError:
        logger.exception("get_model_evaluation_status failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid UUID format.")


@router.get(
    "/evaluations/{evaluation_id}",
    response_model=EvaluationStatusResponse,
    summary="Get evaluation status and progress",
)
async def get_evaluation_status(
    evaluation_id: str,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    eval_service: EvaluationOrchestrationService = Depends(get_eval_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        result = eval_service.getEvaluationStatus(UUID(evaluation_id))
        return EvaluationStatusResponse(**result)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError:
        logger.exception("get_evaluation_status failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid UUID format.")


@router.get(
    "/evaluations/{evaluation_id}/results",
    response_model=EvaluationResultsResponse,
    summary="Get evaluation results with aggregated metrics",
)
async def get_evaluation_results(
    evaluation_id: str,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    eval_service: EvaluationOrchestrationService = Depends(get_eval_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        result = eval_service.getEvaluationResults(UUID(evaluation_id))
        return EvaluationResultsResponse(**result)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except ValueError:
        logger.exception("get_evaluation_results failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid UUID format.")


@router.put(
    "/evaluations/{evaluation_id}/retry",
    response_model=RetryEvaluationResponse,
    summary="Retry a failed evaluation (host/staff only)",
)
async def retry_evaluation(
    evaluation_id: str,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    eval_service: EvaluationOrchestrationService = Depends(get_eval_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        result = eval_service.retryFailedEvaluation(UUID(evaluation_id))
        return RetryEvaluationResponse(**result)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except ValueError:
        logger.exception("retry_evaluation failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid UUID format.")


@router.get(
    "/competitions/{comp_id}/evaluations",
    response_model=CompetitionEvaluationsResponse,
    summary="List all evaluations for a competition",
)
async def get_competition_evaluations(
    comp_id: str,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    eval_service: EvaluationOrchestrationService = Depends(get_eval_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        jobs = eval_service.getCompetitionEvaluations(UUID(comp_id))
        evaluations = [EvaluationJobResponse.model_validate(job) for job in jobs]
        return CompetitionEvaluationsResponse(evaluations=evaluations)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError:
        logger.exception("get_competition_evaluations failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid UUID format.")


@router.get(
    "/competitions/{comp_id}/results",
    response_model=CompetitionResultsResponse,
    summary="Get final competition results with team rankings",
)
async def get_competition_results(
    comp_id: str,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    eval_service: EvaluationOrchestrationService = Depends(get_eval_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        result = eval_service.getCompetitionResults(UUID(comp_id))
        return CompetitionResultsResponse(**result)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError:
        logger.exception("get_competition_results failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid UUID format.")
