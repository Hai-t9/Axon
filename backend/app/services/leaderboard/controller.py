from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, NotFoundError
from app.schemas.leaderboard import LeaderboardResponse
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

from .repository import LeaderboardRepository
from .service import LeaderboardService

router = APIRouter(prefix="/competitions/{comp_id}/leaderboard", tags=["leaderboard"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_leaderboard_service(db: Session = Depends(get_db)) -> LeaderboardService:
    return LeaderboardService(LeaderboardRepository(db))


@router.get("", response_model=LeaderboardResponse)
async def get_leaderboard(
    comp_id: UUID,
    authorization: str = Header(...),
    limit: int | None = Query(None, ge=1, le=100),
    auth_service: AuthService = Depends(get_auth_service),
    leaderboard_service: LeaderboardService = Depends(get_leaderboard_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        return leaderboard_service.get_leaderboard(comp_id, limit)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
