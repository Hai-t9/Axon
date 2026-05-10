import logging
import traceback
from uuid import UUID

from fastapi import APIRouter, Depends, File, Header, HTTPException, Query, UploadFile
from sqlalchemy.orm import Session

logger = logging.getLogger("model_submission.controller")

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import (
    AuthenticationError,
    AuthorizationError,
    NotFoundError,
    ValidationError,
)
from app.models import RoleType
from app.schemas.model_submission import (
    ModelHistoryResponse,
    ModelListResponse,
    ModelResponse,
    ModelScheduleResponse,
    ModelSubmitResponse,
)
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

from .repository import ModelSubmissionRepository
from .service import ModelSubmissionService

router = APIRouter(tags=["model_submission"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_model_service(db: Session = Depends(get_db)) -> ModelSubmissionService:
    return ModelSubmissionService(ModelSubmissionRepository(db))


# ------------------------------------------------------------------ #
#  Submit                                                             #
# ------------------------------------------------------------------ #


@router.post(
    "/competitions/{comp_id}/models/submit",
    response_model=ModelSubmitResponse,
    summary="Submit a model for evaluation",
    description=(
        "Upload a .zip Docker build context. "
        "The zip must contain: Dockerfile, inference.py, requirements.txt, "
        "a model/ directory, and an empty data/ directory. "
        "Exact requirements are defined by the organizer in the competition config."
    ),
)
async def submit_model(
    comp_id: str,
    team_id: str = Query(..., description="ID of the team submitting"),
    model_name: str = Query(..., description="Human-readable model name"),
    framework: str = Query(
        ..., description="ML framework (pytorch | tensorflow | sklearn | keras | onnx)"
    ),
    python_version: str = Query(..., description="Python version used (e.g. 3.9)"),
    framework_version: str = Query(None, description="Framework version (optional)"),
    description: str = Query(None, description="Short description (optional)"),
    file: UploadFile = File(..., description="The .zip Docker build context"),
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    model_service: ModelSubmissionService = Depends(get_model_service),
):
    try:
        comp_uuid = UUID(comp_id)
        team_uuid = UUID(team_id)

        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        auth_service.require_roles(token, comp_uuid, {RoleType.participant})

        metadata = {
            "model_name": model_name,
            "framework": framework,
            "python_version": python_version,
            "framework_version": framework_version,
            "description": description,
            "dependencies": None,
            "input_shape": None,
            "output_shape": None,
            "training_dataset": None,
            "performance_metrics": None,
        }

        result = await model_service.submit_model(
            team_id=team_uuid,
            competition_id=comp_uuid,
            file=file,
            metadata=metadata,
            user_id=user.id,  # type: ignore[arg-type]
        )

        return ModelSubmitResponse(**result)

    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except ValueError:
        logger.exception("submit_model failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid UUID format.")


# ------------------------------------------------------------------ #
#  Spec preview (so participants know what to submit)                 #
# ------------------------------------------------------------------ #


@router.get(
    "/competitions/{comp_id}/models/spec",
    summary="Get the submission spec for this competition",
    description="Returns the organizer-defined requirements for model submissions (required files, model format, etc.).",
)
async def get_submission_spec(
    comp_id: str,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    model_service: ModelSubmissionService = Depends(get_model_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        spec = model_service.get_competition_model_spec(UUID(comp_id))
        return {"competition_id": comp_id, "model_spec": spec}

    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValueError:
        logger.exception("get_submission_spec failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid UUID format.")


# ------------------------------------------------------------------ #
#  List                                                               #


@router.get(
    "/competitions/{comp_id}/models",
    response_model=ModelListResponse,
    summary="List all model submissions for a competition",
)
async def list_models_by_competition(
    comp_id: str,
    authorization: str = Header(...),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    auth_service: AuthService = Depends(get_auth_service),
    model_service: ModelSubmissionService = Depends(get_model_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        result = model_service.get_models_by_competition(UUID(comp_id), page, limit)
        return ModelListResponse(
            items=result["models"],
            total=result["total"],
            page=page,
            limit=limit,
        )

    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValueError:
        logger.exception("list_models_by_competition failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid UUID format.")


@router.get(
    "/teams/{team_id}/models",
    response_model=ModelListResponse,
    summary="List all models submitted by a team",
)
async def list_team_models(
    team_id: str,
    authorization: str = Header(...),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    auth_service: AuthService = Depends(get_auth_service),
    model_service: ModelSubmissionService = Depends(get_model_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        result = model_service.get_team_models(UUID(team_id), page, limit)
        return ModelListResponse(
            items=result["models"],
            total=result["total"],
            page=page,
            limit=limit,
        )

    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValueError:
        logger.exception("get_team_model_history failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid UUID format.")


@router.get(
    "/models/{model_id}",
    response_model=ModelResponse,
    summary="Get model submission details",
)
async def get_team_model_history(
    team_id: str,
    competition_id: str = Query(..., description="Competition ID"),
    authorization: str = Header(...),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    auth_service: AuthService = Depends(get_auth_service),
    model_service: ModelSubmissionService = Depends(get_model_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        result = model_service.get_team_model_history(
            UUID(team_id), UUID(competition_id), page, limit
        )
        return ModelHistoryResponse(
            models=result["models"],
            total=result["total"],
            versions=result["versions"],
        )

    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid UUID format.")


# ------------------------------------------------------------------ #
#  Single model                                                       #
# ------------------------------------------------------------------ #


@router.get(
    "/models/{model_id}",
    response_model=ModelResponse,
    summary="Get model submission details",
)
async def get_model(
    model_id: str,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    model_service: ModelSubmissionService = Depends(get_model_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        result = model_service.get_model_by_id(UUID(model_id))
        return ModelResponse.model_validate(result)

    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError:
        logger.exception("get_model failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid model ID format.")


@router.put(
    "/models/{model_id}/schedule",
    response_model=ModelScheduleResponse,
    summary="Schedule a model for evaluation (host/staff only)",
)
async def schedule_model_for_evaluation(
    model_id: str,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    model_service: ModelSubmissionService = Depends(get_model_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        result = model_service.schedule_model_for_evaluation(UUID(model_id))
        return ModelScheduleResponse(**result)

    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except ValueError:
        logger.exception("schedule_model_for_evaluation failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid model ID format.")


@router.delete(
    "/models/{model_id}",
    summary="Delete a model submission (host/staff only)",
)
async def delete_model(
    model_id: str,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    model_service: ModelSubmissionService = Depends(get_model_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        success = model_service.delete_model(UUID(model_id))
        return {"deleted": success, "model_id": model_id}

    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError:
        logger.exception("delete_model failed with ValueError")
        raise HTTPException(status_code=400, detail="Invalid model ID format.")
