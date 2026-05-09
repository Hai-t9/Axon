from fastapi import APIRouter, Depends, Header, HTTPException, Query
from uuid import UUID
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, AuthorizationError, NotFoundError, ValidationError
from app.models import RoleType
from app.schemas.competition import (
    CompetitionConfigBase,
    CompetitionConfigResponse,
    CompetitionCreate,
    CompetitionListResponse,
    CompetitionResponse,
    CompetitionUpdate,
    UserCompetitionInfo,
    UserCompetitionListResponse,
)
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService
from app.schemas.team import TeamResponse

from .repository import CompetitionRepository
from .service import CompetitionService

router = APIRouter(prefix="/competitions", tags=["competition"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_competition_service(db: Session = Depends(get_db)) -> CompetitionService:
    return CompetitionService(CompetitionRepository(db))


@router.post("", response_model=CompetitionResponse)
async def create_competition(
    payload: CompetitionCreate,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    competition_service: CompetitionService = Depends(get_competition_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        return competition_service.create_competition(user.id, payload)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/join", response_model=UserCompetitionInfo)
async def join_competition(
    payload: dict,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    competition_service: CompetitionService = Depends(get_competition_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        invitation_link = payload.get("invitation_link", "")
        result = competition_service.join_competition(user.id, invitation_link)
        return competition_service.build_user_competition_info(user, result)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/{competition_id}/leave")
async def leave_competition(
    competition_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    competition_service: CompetitionService = Depends(get_competition_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        return competition_service.leave_competition(user.id, competition_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/mine", response_model=UserCompetitionListResponse)
async def list_my_competitions(
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    competition_service: CompetitionService = Depends(get_competition_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        items = competition_service.list_my_competitions(user)
        return {"items": items}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.get("", response_model=CompetitionListResponse)
async def list_competitions(
    authorization: str = Header(...),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    auth_service: AuthService = Depends(get_auth_service),
    competition_service: CompetitionService = Depends(get_competition_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        items, total = competition_service.list_competitions(user.id, page, limit)
        return {
            "items": items,
            "total": total,
            "page": page,
            "limit": limit,
        }
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except Exception as exc:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(exc))


@router.get("/{competition_id}/my-team", response_model=TeamResponse)
async def get_my_team(
    competition_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    competition_service: CompetitionService = Depends(get_competition_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        return competition_service.get_my_team(user, competition_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/{competition_id}", response_model=CompetitionResponse)
async def get_competition(
    competition_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    competition_service: CompetitionService = Depends(get_competition_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        return competition_service.get_competition(competition_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.put("/{competition_id}", response_model=CompetitionResponse)
async def update_competition(
    competition_id: UUID,
    payload: CompetitionUpdate,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    competition_service: CompetitionService = Depends(get_competition_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.require_roles(token, competition_id, {RoleType.host})
        return competition_service.update_competition(competition_id, payload)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.delete("/{competition_id}")
async def delete_competition(
    competition_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    competition_service: CompetitionService = Depends(get_competition_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.require_roles(token, competition_id, {RoleType.host})
        deleted_id = competition_service.delete_competition(competition_id)
        return {"deleted": True, "id": deleted_id}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/{competition_id}/config", response_model=CompetitionConfigResponse)
async def get_competition_config(
    competition_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    competition_service: CompetitionService = Depends(get_competition_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        return competition_service.get_competition_config(competition_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.put("/{competition_id}/config", response_model=CompetitionConfigResponse)
async def update_competition_config(
    competition_id: UUID,
    payload: CompetitionConfigBase,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    competition_service: CompetitionService = Depends(get_competition_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.require_roles(token, competition_id, {RoleType.host})
        updates = payload.dict(exclude_unset=True)
        return competition_service.update_competition_config(competition_id, updates)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))

