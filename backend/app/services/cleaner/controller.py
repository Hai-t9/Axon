import uuid
from datetime import datetime

from fastapi import APIRouter, BackgroundTasks, Depends
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.schemas.cleaner import (
    CleanDatasetResponse,
    CleanerRunResponse,
    DuplicateGroup,
    OptimizeStorageResponse,
    ScanDuplicatesResponse,
)
from app.services.cleaner.repository import CleanerRepository
from app.services.cleaner.service import CleanerService


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


router = APIRouter(tags=["cleaner"])


async def run_pipeline_task(comp_id: int):
    db = SessionLocal()
    try:
        repo = CleanerRepository(db)
        service = CleanerService(repo)
        await service.run_cleaning_pipeline(comp_id)
    finally:
        db.close()


async def clean_dataset_task(team_id: int):
    db = SessionLocal()
    try:
        repo = CleanerRepository(db)
        service = CleanerService(repo)
        await service.clean_dataset_by_team(team_id)
    finally:
        db.close()


@router.post("/competitions/{comp_id}/cleaner/run", response_model=CleanerRunResponse)
async def run_pipeline(
    comp_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    job_id = str(uuid.uuid4())
    background_tasks.add_task(run_pipeline_task, comp_id)
    return {
        "job_id": job_id,
        "status": "queued",
        "message": "Cleaning pipeline has been queued.",
    }


# ── Fix 1: scan-duplicates now returns real data ─────────
@router.post(
    "/competitions/{comp_id}/cleaner/scan-duplicates",
    response_model=ScanDuplicatesResponse,
)
async def scan_duplicates(comp_id: int, db: Session = Depends(get_db)):
    repo = CleanerRepository(db)
    service = CleanerService(repo)
    groups = await service.get_duplicate_groups(comp_id)
    return {
        "duplicate_groups": [
            DuplicateGroup(hash=g["hash"], image_ids=g["image_ids"]) for g in groups
        ],
        "total_duplicates": sum(len(g["image_ids"]) for g in groups),
    }


# ── Fix 4: clean_dataset now runs real logic ─────────────
@router.post(
    "/teams/{team_id}/cleaner/clean",
    response_model=CleanDatasetResponse,
)
async def clean_dataset(
    team_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    background_tasks.add_task(clean_dataset_task, team_id)
    return {
        "images_processed": -1,
        "issues_found": ["Processing in background — results will be stored in DB"],
    }


@router.post(
    "/competitions/{comp_id}/cleaner/optimize-storage",
    response_model=OptimizeStorageResponse,
)
async def optimize_storage(comp_id: int, db: Session = Depends(get_db)):
    repo = CleanerRepository(db)
    service = CleanerService(repo)
    stats = await service.optimize_storage(comp_id)
    return {
        "freed_mb": stats["freed_mb"],
        "files_removed": stats["files_removed"],
        "completed_at": datetime.utcnow(),
    }
