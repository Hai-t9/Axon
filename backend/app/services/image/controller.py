from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException, Header
from sqlalchemy.orm import Session
from app.schemas.image import ImageResponse
from app.services.image.service import ImageService
from app.services.image.repository import ImageRepository
from app.core.database import SessionLocal
from app.core.auth import extract_bearer_token
from app.core.exceptions import AuthenticationError
from app.services.auth.repository import AuthRepository
from app.services.auth.service import AuthService
from app.models import PhaseLog
from typing import List, Optional
from pydantic import BaseModel
from uuid import UUID

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


def get_current_user_id(
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
) -> UUID:
    token = extract_bearer_token(authorization)
    try:
        user = auth_service.get_current_user(token)
        return user.id
    except AuthenticationError:
        return UUID(int=0)


router = APIRouter(tags=["images"])

class ImageUpdateStatus(BaseModel):
    status: str

@router.post("/teams/{team_id}/images", response_model=ImageResponse)
async def upload_image(
    team_id: UUID,
    file: UploadFile = File(...),
    label: str = Form(None),
    metadata: str = Form(None),
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id)
):
    repo = ImageRepository(db)
    service = ImageService(repo)

    comp_id = repo.get_comp_id(team_id)
    if comp_id:
        phase = db.query(PhaseLog).filter(PhaseLog.competition_id == comp_id).first()
        if phase and phase.current_phase != "1":
            raise HTTPException(
                status_code=400,
                detail="Image upload is only allowed during the Data Collection phase."
            )

    try:
        record = await service.upload_image(current_user_id, team_id, file, label)
        return record
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/images/{image_id}", response_model=ImageResponse)
def get_image(image_id: UUID, db: Session = Depends(get_db)):
    repo = ImageRepository(db)
    service = ImageService(repo)
    image = service.get_image_by_id(image_id)
    if not image:
        raise HTTPException(status_code=404, detail="Image not found")
    return image

@router.get("/teams/{team_id}/images", response_model=dict)
def get_team_images(
    team_id: UUID,
    status: str = None,
    author_id: UUID = None,
    label: str = None,
    page: int = 1,
    limit: int = 50,
    db: Session = Depends(get_db)
):
    repo = ImageRepository(db)
    service = ImageService(repo)
    images, total = service.get_images_by_team(team_id, status, author_id, label, page, limit)
    result = []
    for img in images:
        d = ImageResponse.model_validate(img).model_dump()
        d['author_name'] = img.author.fullname if img.author else None
        result.append(d)
    return {
        "images": result,
        "total": total,
        "page": page
    }

@router.get("/competitions/{comp_id}/images", response_model=dict)
def get_comp_images(
    comp_id: UUID,
    status: str = None,
    db: Session = Depends(get_db)
):
    repo = ImageRepository(db)
    service = ImageService(repo)
    images, total = service.get_images_by_competition(comp_id, status)
    return {
        "images": [ImageResponse.model_validate(img).model_dump() for img in images],
        "total": total
    }

@router.get("/competitions/{comp_id}/images/stats", response_model=dict)
def get_comp_image_stats(
    comp_id: UUID,
    db: Session = Depends(get_db)
):
    repo = ImageRepository(db)
    service = ImageService(repo)
    return service.get_image_stats(comp_id)

@router.patch("/images/{image_id}/status", response_model=ImageResponse)
def update_image_status(image_id: UUID, status_update: ImageUpdateStatus, db: Session = Depends(get_db)):
    repo = ImageRepository(db)
    service = ImageService(repo)
    try:
        updated = service.update_image_status(image_id, status_update.status)
        return updated
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.delete("/images/{image_id}")
def delete_image(image_id: UUID, db: Session = Depends(get_db)):
    repo = ImageRepository(db)
    service = ImageService(repo)
    try:
        service.delete_image(image_id)
        return {"message": "Image deleted"}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
