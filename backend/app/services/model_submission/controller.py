"""
FILE: backend/app/services/model_submission/controller.py
"""

from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile
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
from app.schemas.model_submission import ModelListResponse, ModelResponse
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


# -----------------------------------------------------------------------
# POST /competitions/{comp_id}/teams/{team_id}/models
#   Submit a Docker model image for evaluation.
#   Restricted to: participant role (team member) or host/staff.
#   Phase restriction: evaluation phase only (enforced in service).
# -----------------------------------------------------------------------
@router.post(
    "/competitions/{comp_id}/teams/{team_id}/models",
    response_model=ModelResponse,
    summary="Submit a model for evaluation",
)
async def submit_model(
    comp_id: int,
    team_id: int,
    file: UploadFile = File(..., description="Docker image archive (.tar / .tar.gz / .zip)"),
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    """
    Upload a trained model (Docker image archive) for evaluation.

    **Phase restriction:** Only allowed when the competition is in the
    *evaluation* phase.

    **Role restriction:** The caller must be authenticated. The
    system allows host, staff, or any participant who is a member of
    the target team.
    """
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)

        # Check if user is in the team
        from app.models import Team
        team = db.query(Team).filter(Team.id == team_id).first()
        if not team or user.id not in (team.user_ids or []):
            # Also allow host to submit for any team? No, only team members.
            raise AuthorizationError("User is not a member of this team")

        service = ModelSubmissionService(ModelSubmissionRepository(db))
        model = await service.submit_model(
            team_id=team_id,
            competition_id=comp_id,
            file=file,
            db=db,
        )
        return model
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


# -----------------------------------------------------------------------
# GET /teams/{team_id}/models
#   List all models submitted by a team.
# -----------------------------------------------------------------------
@router.get(
    "/teams/{team_id}/models",
    response_model=ModelListResponse,
    summary="List models submitted by a team",
)
async def list_team_models(
    team_id: int,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        service = ModelSubmissionService(ModelSubmissionRepository(db))
        items = service.list_by_team(team_id)
        return {"items": items, "total": len(items)}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


# -----------------------------------------------------------------------
# GET /competitions/{comp_id}/models
#   List all model submissions for a competition (host/staff only).
# -----------------------------------------------------------------------
@router.get(
    "/competitions/{comp_id}/models",
    response_model=ModelListResponse,
    summary="List all models submitted to a competition",
)
async def list_competition_models(
    comp_id: int,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.require_roles(token, comp_id, {RoleType.host, RoleType.staff})

        service = ModelSubmissionService(ModelSubmissionRepository(db))
        items = service.list_by_competition(comp_id)
        return {"items": items, "total": len(items)}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


# -----------------------------------------------------------------------
# GET /models/{model_id}
#   Get a single model by ID.
# -----------------------------------------------------------------------
@router.get(
    "/models/{model_id}",
    response_model=ModelResponse,
    summary="Get model details",
)
async def get_model(
    model_id: int,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)

        service = ModelSubmissionService(ModelSubmissionRepository(db))
        return service.get_model(model_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


# -----------------------------------------------------------------------
# DELETE /models/{model_id}
#   Delete a model submission (host/staff only).
# -----------------------------------------------------------------------
@router.delete(
    "/models/{model_id}",
    summary="Delete a model submission",
)
async def delete_model(
    model_id: int,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    try:
        token = extract_bearer_token(authorization)

        # Fetch model first to get competition_id for role check.
        service = ModelSubmissionService(ModelSubmissionRepository(db))
        model = service.get_model(model_id)

        auth_service.require_roles(token, model.competition_id, {RoleType.host, RoleType.staff})

        deleted_id = service.delete_model(model_id)
        return {"deleted": True, "id": deleted_id}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))