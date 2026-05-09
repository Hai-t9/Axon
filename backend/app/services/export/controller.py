from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session
from uuid import UUID

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, AuthorizationError, NotFoundError, ValidationError
from app.models import RoleType
from app.schemas.export import ExportResponse
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService

from .repository import ExportRepository
from .service import ExportService

router = APIRouter(prefix="/competitions/{comp_id}/export", tags=["export"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_export_service(db: Session = Depends(get_db)) -> ExportService:
    return ExportService(ExportRepository(db), db=db)


@router.get("/team-data", response_model=ExportResponse)
async def export_team_data(
    comp_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    export_service: ExportService = Depends(get_export_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)
        return export_service.export_team_data(comp_id, user.id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/full-data", response_model=ExportResponse)
async def export_full_data(
    comp_id: UUID,
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    export_service: ExportService = Depends(get_export_service),
):
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.require_roles(token, comp_id, {RoleType.host})
        return export_service.export_full_data(comp_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except AuthorizationError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
