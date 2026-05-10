from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, ValidationError
from app.schemas.user import AuthResponse, LoginRequest, SignupRequest, UserResponse
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


@router.get("/me", response_model=UserResponse)
async def get_me(
    authorization: str = Header(...),
    auth_service: AuthService = Depends(
        lambda db: AuthService(AuthRepository(db))
    ),
):
    try:
        from app.core.auth import extract_bearer_token
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        return UserResponse(
            id=user.id,
            email=user.email,
            fullname=user.fullname,
            created_at=user.created_at,
        )
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))

