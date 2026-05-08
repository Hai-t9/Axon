from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy.orm import Session

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
)
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

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
        items, total = competition_service.list_competitions(page, limit, user_id=user.id)
        return {
            "items": items,
            "total": total,
            "page": page,
            "limit": limit,
        }
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.get("/{competition_id}", response_model=CompetitionResponse)
async def get_competition(
    competition_id: int,
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
    competition_id: int,
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
    competition_id: int,
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
    competition_id: int,
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
    competition_id: int,
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

@router.get("/{competition_id}/my-role")
async def get_my_role(
    competition_id: int,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    db: Session = Depends(get_db)
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        
        from app.models import Role, Team
        import json
        role_entry = db.query(Role).filter_by(user_id=user.id, competition_id=competition_id).first()
        
        team_id = None
        if role_entry and role_entry.role.value == "participant":
            teams_in_comp = db.query(Team).filter(Team.comp_id == competition_id).all()
            for t in teams_in_comp:
                uids = t.user_ids or []
                if isinstance(uids, str):
                    try: uids = json.loads(uids)
                    except: uids = []
                uids_int = []
                for uid in uids:
                    try: uids_int.append(int(uid))
                    except: pass
                if user.id in uids_int:
                    team_id = t.id
                    break

        return {
            "role": role_entry.role.value if role_entry else "none",
            "team_id": team_id
        }
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


