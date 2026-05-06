from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from datetime import datetime
import uuid
from app.schemas.cleaner import (
    CleanerRunResponse, ScanDuplicatesResponse,
    CleanDatasetResponse, OptimizeStorageResponse
)
from app.services.cleaner.service import CleanerService
from app.services.cleaner.repository import CleanerRepository
from app.core.database import SessionLocal

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

router = APIRouter(tags=["cleaner"])

async def run_pipeline_task(comp_id: int):
    # In a real app we'd need a separate DB session for the background task
    db = SessionLocal()
    try:
        repo = CleanerRepository(db)
        service = CleanerService(repo)
        await service.run_cleaning_pipeline(comp_id)
    finally:
        db.close()

@router.post("/competitions/{comp_id}/cleaner/run", response_model=CleanerRunResponse)
async def run_pipeline(comp_id: int, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    job_id = str(uuid.uuid4())
    background_tasks.add_task(run_pipeline_task, comp_id)
    return {
        "job_id": job_id,
        "status": "queued",
        "message": "Cleaning pipeline has been queued."
    }

@router.post("/competitions/{comp_id}/cleaner/scan-duplicates", response_model=ScanDuplicatesResponse)
async def scan_duplicates(comp_id: int, db: Session = Depends(get_db)):
    repo = CleanerRepository(db)
    service = CleanerService(repo)
    duplicates = await service.scan_for_duplicates(comp_id)
    return {
        "duplicate_groups": [],
        "total_duplicates": len(duplicates)
    }

@router.post("/teams/{team_id}/cleaner/clean", response_model=CleanDatasetResponse)
async def clean_dataset(team_id: int, db: Session = Depends(get_db)):
    # Mocking implementation
    return {
        "images_processed": 10,
        "issues_found": ["Missing Labels"]
    }

@router.post("/competitions/{comp_id}/cleaner/optimize-storage", response_model=OptimizeStorageResponse)
async def optimize_storage(comp_id: int, db: Session = Depends(get_db)):
    repo = CleanerRepository(db)
    service = CleanerService(repo)
    stats = await service.optimize_storage()
    return {
        "freed_mb": stats["freed_mb"],
        "files_removed": stats["files_removed"],
        "completed_at": datetime.utcnow()
    }
