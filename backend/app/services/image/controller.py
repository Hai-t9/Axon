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


@router.get("/competitions/{comp_id}/dataset/export")
def export_dataset(
    comp_id: int,
    format: str = "csv",
    authorization: str = Header(None),
    token: str = None,
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    """Export a competition's dataset as a ZIP in specific formats (csv, yolo, coco)."""
    import io, csv, zipfile, os, json
    from fastapi.responses import StreamingResponse
    from app.models import Image, Team, Label

    try:
        jwt_token = extract_bearer_token(authorization) if authorization else token
        if not jwt_token:
            raise AuthenticationError("No token provided")
        auth_service.get_current_user(jwt_token)

        images = db.query(Image).join(Team, Team.id == Image.team_id).filter(Team.comp_id == comp_id).all()

        buf = io.BytesIO()
        with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zf:
            if format == "csv":
                csv_buf = io.StringIO()
                writer = csv.writer(csv_buf)
                writer.writerow(['filename', 'label', 'team_id', 'status'])
                for img in images:
                    label_record = db.query(Label).filter(Label.image_id == img.id).first()
                    label_text = label_record.label if label_record else (img.label or 'unlabeled')
                    filename = os.path.basename(img.filepath) if img.filepath else f"image_{img.id}.jpg"
                    writer.writerow([filename, label_text, img.team_id, img.status.value if img.status else 'unknown'])
                    if img.filepath and os.path.exists(img.filepath):
                        zf.write(img.filepath, f"images/{filename}")
                zf.writestr("labels.csv", csv_buf.getvalue())
                
            elif format == "yolo":
                for img in images:
                    label_record = db.query(Label).filter(Label.image_id == img.id).first()
                    label_text = label_record.label if label_record else (img.label or 'unlabeled')
                    filename = os.path.basename(img.filepath) if img.filepath else f"image_{img.id}.jpg"
                    # YOLO classification format: class_name/image.jpg
                    if img.filepath and os.path.exists(img.filepath):
                        zf.write(img.filepath, f"{label_text}/{filename}")
                        
            elif format == "coco":
                coco_data = {
                    "info": {"description": f"Axon Competition {comp_id} Dataset"},
                    "images": [],
                    "annotations": [],
                    "categories": []
                }
                categories_map = {}
                cat_id = 1
                for img in images:
                    label_record = db.query(Label).filter(Label.image_id == img.id).first()
                    label_text = label_record.label if label_record else (img.label or 'unlabeled')
                    if label_text not in categories_map:
                        categories_map[label_text] = cat_id
                        coco_data["categories"].append({"id": cat_id, "name": label_text})
                        cat_id += 1
                        
                    filename = os.path.basename(img.filepath) if img.filepath else f"image_{img.id}.jpg"
                    coco_data["images"].append({"id": img.id, "file_name": filename})
                    coco_data["annotations"].append({
                        "id": img.id,
                        "image_id": img.id,
                        "category_id": categories_map[label_text]
                    })
                    if img.filepath and os.path.exists(img.filepath):
                        zf.write(img.filepath, f"images/{filename}")
                zf.writestr("annotations.json", json.dumps(coco_data, indent=2))

        buf.seek(0)
        return StreamingResponse(
            buf,
            media_type="application/zip",
            headers={"Content-Disposition": f"attachment; filename=competition_{comp_id}_dataset.zip"}
        )
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))


@router.get("/teams/{team_id}/dataset/export")
def export_team_dataset(
    team_id: int,
    format: str = "csv",
    authorization: str = Header(None),
    token: str = None,
    db: Session = Depends(get_db),
    auth_service: AuthService = Depends(get_auth_service),
):
    """Export a single team's dataset as a ZIP containing only their images and labels.csv."""
    import io, csv, zipfile, os, json
    from fastapi.responses import StreamingResponse
    from app.models import Image, Team, Label

    try:
        jwt_token = extract_bearer_token(authorization) if authorization else token
        if not jwt_token:
            raise AuthenticationError("No token provided")
        user = auth_service.get_current_user(jwt_token)

        team = db.query(Team).filter(Team.id == team_id).first()
        if not team:
            raise HTTPException(status_code=404, detail="Team not found")

        user_ids = team.user_ids or []
        from app.models import Role, RoleType
        is_host = db.query(Role).filter(Role.user_id == user.id, Role.competition_id == team.comp_id, Role.role == RoleType.host).first()
        if user.id not in [int(uid) for uid in user_ids] and not is_host:
            raise HTTPException(status_code=403, detail="You can only export your own team's dataset")

        images = db.query(Image).filter(Image.team_id == team_id).all()

        buf = io.BytesIO()
        with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zf:
            if format == "csv":
                csv_buf = io.StringIO()
                writer = csv.writer(csv_buf)
                writer.writerow(['filename', 'label', 'status'])
                for img in images:
                    label_record = db.query(Label).filter(Label.image_id == img.id).first()
                    label_text = label_record.label if label_record else (img.label or 'unlabeled')
                    filename = os.path.basename(img.filepath) if img.filepath else f"image_{img.id}.jpg"
                    writer.writerow([filename, label_text, img.status.value if img.status else 'unknown'])
                    if img.filepath and os.path.exists(img.filepath):
                        zf.write(img.filepath, f"images/{filename}")
                zf.writestr("labels.csv", csv_buf.getvalue())
            elif format == "yolo":
                for img in images:
                    label_record = db.query(Label).filter(Label.image_id == img.id).first()
                    label_text = label_record.label if label_record else (img.label or 'unlabeled')
                    filename = os.path.basename(img.filepath) if img.filepath else f"image_{img.id}.jpg"
                    if img.filepath and os.path.exists(img.filepath):
                        zf.write(img.filepath, f"{label_text}/{filename}")
            elif format == "coco":
                coco_data = {"info": {"description": f"Team {team_id} Dataset"}, "images": [], "annotations": [], "categories": []}
                categories_map = {}
                cat_id = 1
                for img in images:
                    label_record = db.query(Label).filter(Label.image_id == img.id).first()
                    label_text = label_record.label if label_record else (img.label or 'unlabeled')
                    if label_text not in categories_map:
                        categories_map[label_text] = cat_id
                        coco_data["categories"].append({"id": cat_id, "name": label_text})
                        cat_id += 1
                    filename = os.path.basename(img.filepath) if img.filepath else f"image_{img.id}.jpg"
                    coco_data["images"].append({"id": img.id, "file_name": filename})
                    coco_data["annotations"].append({"id": img.id, "image_id": img.id, "category_id": categories_map[label_text]})
                    if img.filepath and os.path.exists(img.filepath):
                        zf.write(img.filepath, f"images/{filename}")
                zf.writestr("annotations.json", json.dumps(coco_data, indent=2))

        buf.seek(0)
        return StreamingResponse(
            buf,
            media_type="application/zip",
            headers={"Content-Disposition": f"attachment; filename=team_{team_id}_dataset.zip"}
        )
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))