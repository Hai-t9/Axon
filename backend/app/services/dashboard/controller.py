from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, NotFoundError
from app.schemas.dashboard import DashboardResponse
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


def get_dashboard_service(db: Session = Depends(get_db)) -> DashboardService:
    return DashboardService(DashboardRepository(db))


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
