from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, ValidationError
from app.schemas.user import AuthResponse, LoginRequest, SignupRequest

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

