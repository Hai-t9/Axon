from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, AuthorizationError, NotFoundError, ValidationError
from app.models import RoleType
from app.schemas.team import (
    TeamCreate,
    TeamListResponse,
    TeamMembersResponse,
    TeamResponse,
    TeamStatisticsResponse,
    TeamUpdate,
)
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

from .repository import TeamRepository
from .service import TeamService

router = APIRouter(tags=["team"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_team_service(db: Session = Depends(get_db)) -> TeamService:
    return TeamService(TeamRepository(db))


@router.post("/competitions/{comp_id}/teams", response_model=TeamResponse)
async def create_team(
    comp_id: UUID,
    payload: TeamCreate,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    team_service: TeamService = Depends(get_team_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.require_roles(token, comp_id, {RoleType.host, RoleType.staff})
        return team_service.create_team(comp_id, payload)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/competitions/{comp_id}/teams/bulk")
async def bulk_create_teams(
    comp_id: UUID,
    payload: dict,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    team_service: TeamService = Depends(get_team_service),
):
    """Bulk-create teams from a dict of {team_name: [email1, email2, ...]}."""
    try:
        token = extract_bearer_token(authorization)
        auth_service.require_roles(token, comp_id, {RoleType.host, RoleType.staff})
        teams_data = payload.get("teams", {})
        result = team_service.bulk_create_teams(comp_id, teams_data)
        return result
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/competitions/{comp_id}/teams", response_model=TeamListResponse)
async def list_teams(
    comp_id: UUID,
    authorization: str = Header(...),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    auth_service: AuthService = Depends(get_auth_service),
    team_service: TeamService = Depends(get_team_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        items, total = team_service.list_teams(comp_id, page, limit)
        return {"items": items, "total": total, "page": page, "limit": limit}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.get("/teams/{team_id}", response_model=TeamResponse)
async def get_team(
    team_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    team_service: TeamService = Depends(get_team_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        return team_service.get_team(team_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.put("/teams/{team_id}", response_model=TeamResponse)
async def update_team(
    team_id: UUID,
    payload: TeamUpdate,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    team_service: TeamService = Depends(get_team_service),
):
    try:
        token = extract_bearer_token(authorization)
        team = team_service.get_team(team_id)
        auth_service.require_roles(token, team.comp_id, {RoleType.host, RoleType.staff})
        return team_service.update_team(team_id, payload)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.delete("/teams/{team_id}")
async def delete_team(
    team_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    team_service: TeamService = Depends(get_team_service),
):
    try:
        token = extract_bearer_token(authorization)
        team = team_service.get_team(team_id)
        auth_service.require_roles(token, team.comp_id, {RoleType.host})
        deleted_id = team_service.delete_team(team_id)
        return {"deleted": True, "id": deleted_id}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/teams/{team_id}/members", response_model=TeamMembersResponse)
async def get_team_members(
    team_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    team_service: TeamService = Depends(get_team_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        members = team_service.get_members(team_id)
        return {"members": members, "total": len(members)}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post("/teams/{team_id}/members", response_model=TeamResponse)
async def add_team_member(
    team_id: UUID,
    payload: dict,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    team_service: TeamService = Depends(get_team_service),
):
    """Add a member by email."""
    try:
        token = extract_bearer_token(authorization)
        team = team_service.get_team(team_id)
        auth_service.require_roles(token, team.comp_id, {RoleType.host, RoleType.staff})
        email = payload.get("email", "").strip()
        if not email:
            raise ValidationError("Email is required")
        return team_service.add_member_by_email(team_id, email)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.delete("/teams/{team_id}/members/{email:path}")
async def remove_team_member(
    team_id: UUID,
    email: str,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    team_service: TeamService = Depends(get_team_service),
):
    """Remove a member by email."""
    try:
        token = extract_bearer_token(authorization)
        team = team_service.get_team(team_id)
        auth_service.require_roles(token, team.comp_id, {RoleType.host, RoleType.staff})
        team_service.remove_member_by_email(team_id, email)
        return {"removed": True, "team_id": team_id, "email": email}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post("/teams/{team_id}/members/by-email", response_model=TeamResponse)
async def add_team_member_by_email(
    team_id: UUID,
    payload: dict,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    team_service: TeamService = Depends(get_team_service),
):
    try:
        token = extract_bearer_token(authorization)
        team = team_service.get_team(team_id)
        auth_service.require_roles(token, team.comp_id, {RoleType.host, RoleType.staff})
        email = payload.get("email", "").strip()
        if not email:
            raise ValidationError("Email is required")
        return team_service.add_member_by_email(team_id, email)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/teams/{team_id}/statistics", response_model=TeamStatisticsResponse)
async def get_team_statistics(
    team_id: int,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    team_service: TeamService = Depends(get_team_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        return team_service.get_statistics(team_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
