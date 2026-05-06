from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class CleanerRunResponse(BaseModel):
    job_id: str
    status: str
    message: str

class CleanerResultResponse(BaseModel):
    duplicates_removed: int
    corrupted_removed: int
    images_normalized: int
    images_resized: int
    datasets_rebuilt: bool
    storage_freed_mb: float
    completed_at: datetime

class DuplicateGroup(BaseModel):
    hash: str
    image_ids: List[int]

class ScanDuplicatesResponse(BaseModel):
    duplicate_groups: List[DuplicateGroup]
    total_duplicates: int

class CleanDatasetResponse(BaseModel):
    images_processed: int
    issues_found: List[str]

class OptimizeStorageResponse(BaseModel):
    freed_mb: float
    files_removed: int
    completed_at: datetime
