from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from app.schemas.cleaner import (
    CleanerRunResponse, ScanDuplicatesResponse,
    CleanDatasetResponse, OptimizeStorageResponse
)
from app.services.cleaner.service import CleanerService
from app.services.cleaner.repository import CleanerRepository
from app.core.database import get_db

router = APIRouter(prefix="/api", tags=["cleaner"])

@router.post("/competitions/{comp_id}/cleaner/run", response_model=CleanerRunResponse)
async def run_pipeline(comp_id: int, db: Session = Depends(get_db)):
    repo = CleanerRepository(db)
    service = CleanerService(repo)
    result = await service.run_cleaning_pipeline(comp_id)
    return result

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
