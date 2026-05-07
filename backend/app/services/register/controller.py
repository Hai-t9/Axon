from fastapi import APIRouter, Depends, Header, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
import io, csv, zipfile, os

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, ValidationError
from app.schemas.user import AuthResponse, LoginRequest, SignupRequest
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

from .repository import RegisterRepository
from .service import RegisterService

router = APIRouter(prefix="/register", tags=["register"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_register_service(db: Session = Depends(get_db)) -> RegisterService:
    repository = RegisterRepository(db)
    return RegisterService(repository)


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


@router.post("/signup", response_model=AuthResponse)
async def signup(
    payload: SignupRequest, service: RegisterService = Depends(get_register_service)
):
    try:
        result = service.signup(payload)
        return result
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/login", response_model=AuthResponse)
async def login(
    payload: LoginRequest, service: RegisterService = Depends(get_register_service)
):
    try:
        result = service.login(payload)
        return result
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.get("/me")
async def get_profile(
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    """Return the current user's full profile with competitions and team memberships."""
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)

        from app.models import Role, Competition, Team
        roles = db.query(Role).filter(Role.user_id == user.id).all()

        competitions = []
        for r in roles:
            comp = db.query(Competition).filter(Competition.id == r.competition_id).first()
            # Find user's team in this competition
            teams_in_comp = db.query(Team).filter(Team.comp_id == r.competition_id).all()
            user_team = None
            for t in teams_in_comp:
                if t.user_ids and user.id in t.user_ids:
                    user_team = {"id": t.id, "name": t.name}
                    break

            competitions.append({
                "id": comp.id if comp else r.competition_id,
                "name": comp.name if comp else "Unknown",
                "role": r.role.value,
                "team": user_team,
            })

        return {
            "id": user.id,
            "fullname": user.fullname,
            "email": user.email,
            "phone": user.phone,
            "created_at": str(user.created_at) if user.created_at else None,
            "competitions": competitions,
        }
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.get("/me/competitions")
async def get_my_competitions(
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    """Return competitions the user belongs to, with their team info."""
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)

        from app.models import Role, Competition, Team
        roles = db.query(Role).filter(Role.user_id == user.id).all()
        result = []
        for r in roles:
            comp = db.query(Competition).filter(Competition.id == r.competition_id).first()
            teams_in_comp = db.query(Team).filter(Team.comp_id == r.competition_id).all()
            user_team = None
            for t in teams_in_comp:
                if t.user_ids and user.id in t.user_ids:
                    user_team = {"id": t.id, "name": t.name}
                    break
            result.append({
                "competition_id": r.competition_id,
                "competition_name": comp.name if comp else "Unknown",
                "role": r.role.value,
                "team": user_team,
            })
        return {"items": result}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))

