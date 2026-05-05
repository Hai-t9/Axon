from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from app.schemas.image import ImageResponse
from app.services.image.service import ImageService
from app.services.image.repository import ImageRepository
from app.core.database import get_db
from typing import List
from pydantic import BaseModel

router = APIRouter(prefix="/api", tags=["images"])

class ImageUpdateStatus(BaseModel):
    status: str

@router.post("/teams/{team_id}/images", response_model=ImageResponse)
async def upload_image(
    team_id: int,
    file: UploadFile = File(...),
    label: str = Form(None),
    db: Session = Depends(get_db)
):
    repo = ImageRepository(db)
    service = ImageService(repo)
    user_id = 1 # mock auth

    try:
        record = await service.upload_image(user_id, team_id, file, label)
        return record
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/images/{image_id}", response_model=ImageResponse)
def get_image(image_id: int, db: Session = Depends(get_db)):
    repo = ImageRepository(db)
    service = ImageService(repo)
    image = service.get_image_by_id(image_id)
    if not image:
        raise HTTPException(status_code=404, detail="Image not found")
    return image

@router.get("/teams/{team_id}/images", response_model=dict)
def get_team_images(
    team_id: int,
    status: str = None,
    page: int = 1,
    db: Session = Depends(get_db)
):
    repo = ImageRepository(db)
    service = ImageService(repo)
    images, total = service.get_images_by_team(team_id, status, page)
    return {
        "images": images,
        "total": total,
        "page": page
    }

@router.get("/competitions/{comp_id}/images", response_model=dict)
def get_comp_images(
    comp_id: int,
    status: str = None,
    db: Session = Depends(get_db)
):
    repo = ImageRepository(db)
    service = ImageService(repo)
    images, total = service.get_images_by_competition(comp_id, status)
    return {
        "images": images,
        "total": total
    }

@router.patch("/images/{image_id}/status", response_model=ImageResponse)
def update_image_status(image_id: int, status_update: ImageUpdateStatus, db: Session = Depends(get_db)):
    repo = ImageRepository(db)
    service = ImageService(repo)
    try:
        updated = service.update_image_status(image_id, status_update.status)
        return updated
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.delete("/images/{image_id}")
def delete_image(image_id: int, db: Session = Depends(get_db)):
    repo = ImageRepository(db)
    service = ImageService(repo)
    try:
        service.delete_image(image_id)
        return {"message": "Image deleted"}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

