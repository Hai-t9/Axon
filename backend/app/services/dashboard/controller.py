from fastapi import APIRouter, Depends, Header, HTTPException, Query
import asyncio
import json
from sse_starlette.sse import EventSourceResponse
from sqlalchemy.orm import Session

from app.core.auth import extract_bearer_token
from app.core.cache import DashboardCache, get_dashboard_cache
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, AuthorizationError, NotFoundError
from app.models import RoleType
from app.schemas.dashboard import (
    DashboardCachedResponse,
    DashboardCacheClearResponse,
    DashboardResponse,
)
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

from .repository import DashboardRepository
from .service import DashboardService

router = APIRouter(prefix="/competitions/{comp_id}/dashboard", tags=["dashboard"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_cache() -> DashboardCache:
    return get_dashboard_cache()


def get_dashboard_service(
    db: Session = Depends(get_db),
    cache: DashboardCache = Depends(get_cache),
) -> DashboardService:
    return DashboardService(DashboardRepository(db), cache)


@router.get("", response_model=DashboardResponse)
async def get_dashboard(
    comp_id: int,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    dashboard_service: DashboardService = Depends(get_dashboard_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        return dashboard_service.get_dashboard(comp_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))

@router.get("/stream")
async def stream_dashboard(
    comp_id: int,
    token: str = Query(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
    dashboard_service: DashboardService = Depends(get_dashboard_service),
):
    try:
        auth_service.get_current_user(token)
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Unauthorized")

    async def event_generator():
        while True:
            try:
                # Refresh db session to get latest state
                # Wait, getting dashboard uses the cached session. It might need a fresh session.
                # Since Depends(get_db) is bound to the request, the session lives as long as the SSE connection.
                # To see updates, we might need to commit or rollback the session to see new transactions in sqlite.
                db.commit()
                data = dashboard_service.get_dashboard(comp_id)
                yield {"event": "update", "data": json.dumps(data)}
            except Exception:
                pass
            await asyncio.sleep(5)
            
    return EventSourceResponse(event_generator())


@router.get("/cache", response_model=DashboardCachedResponse)
async def get_cached_dashboard(
    comp_id: int,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    dashboard_service: DashboardService = Depends(get_dashboard_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        return dashboard_service.get_cached_dashboard(comp_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.delete("/cache", response_model=DashboardCacheClearResponse)
async def clear_dashboard_cache(
    comp_id: int,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    dashboard_service: DashboardService = Depends(get_dashboard_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.require_roles(token, comp_id, {RoleType.host})
        return dashboard_service.clear_dashboard_cache(comp_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
