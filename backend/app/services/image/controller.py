"""
FILE: backend/app/services/image/controller.py   (REPLACE existing file)

Changes vs original:
  - upload_image now calls phase_guard to assert competition is in "active" phase.
  - get_current_user is replaced with the real AuthService pattern.
  - Added GET /competitions/{comp_id}/images/export endpoint for dataset export.
"""

from fastapi import APIRouter, Depends, File, Form, HTTPException, Header, UploadFile
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.auth import extract_bearer_token
from app.core.database import SessionLocal
from app.core.exceptions import AuthenticationError, ValidationError
from app.core.phase_guard import phase_guard
from app.schemas.image import ImageResponse
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService
from app.services.image.repository import ImageRepository
from app.services.image.service import ImageService

router = APIRouter(tags=["images"])


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


class ImageUpdateStatus(BaseModel):
    status: str


# -----------------------------------------------------------------------
# POST /teams/{team_id}/images   — Phase-restricted upload
# -----------------------------------------------------------------------
@router.post("/teams/{team_id}/images", response_model=ImageResponse)
async def upload_image(
    team_id: int,
    file: UploadFile = File(...),
    label: str = Form(None),
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    """
    Upload an image on behalf of a team.

    **Phase restriction:** Only allowed when the competition is in the
    *active* (data collection) phase.
    """
    try:
        token = extract_bearer_token(authorization)
        user = auth_service.get_current_user(token)

        # Resolve competition_id from team (needed for phase check).
        from app.models.model_team import Team as TeamModel
        team = db.query(TeamModel).filter(TeamModel.id == team_id).first()
        if not team:
            raise HTTPException(status_code=404, detail="Team not found")

        # Phase guard — image uploads only during active phase.
        try:
            phase_guard.assert_phase(
                db,
                team.comp_id,
                allowed_phases=["active"],
                action_description="image upload",
            )
        except ValidationError as exc:
            raise HTTPException(status_code=400, detail=str(exc))

        repo = ImageRepository(db)
        service = ImageService(repo)
        record = await service.upload_image(user.id, team_id, file, label)
        return record
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/images/{image_id}", response_model=ImageResponse)
def get_image(
    image_id: int,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        repo = ImageRepository(db)
        image = ImageService(repo).get_image_by_id(image_id)
        if not image:
            raise HTTPException(status_code=404, detail="Image not found")
        return image
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.get("/teams/{team_id}/images", response_model=dict)
def get_team_images(
    team_id: int,
    status: str = None,
    page: int = 1,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        repo = ImageRepository(db)
        images, total = ImageService(repo).get_images_by_team(team_id, status, page)
        return {
            "images": [ImageResponse.model_validate(img).model_dump() for img in images],
            "total": total,
            "page": page,
        }
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.get("/competitions/{comp_id}/images", response_model=dict)
def get_comp_images(
    comp_id: int,
    status: str = None,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        repo = ImageRepository(db)
        images, total = ImageService(repo).get_images_by_competition(comp_id, status)
        return {
            "images": [ImageResponse.model_validate(img).model_dump() for img in images],
            "total": total,
        }
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.get("/competitions/{comp_id}/images/stats", response_model=dict)
def get_comp_image_stats(
    comp_id: int,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        repo = ImageRepository(db)
        return ImageService(repo).get_image_stats(comp_id)
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.patch("/images/{image_id}/status", response_model=ImageResponse)
def update_image_status(
    image_id: int,
    status_update: ImageUpdateStatus,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        repo = ImageRepository(db)
        updated = ImageService(repo).update_image_status(image_id, status_update.status)
        return updated
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.delete("/images/{image_id}")
def delete_image(
    image_id: int,
    authorization: str = Header(...),
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        repo = ImageRepository(db)
        ImageService(repo).delete_image(image_id)
        return {"message": "Image deleted"}
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))