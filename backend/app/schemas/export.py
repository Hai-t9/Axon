from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel


class ExportLabelValidation(BaseModel):
    validator_id: str
    label: str
    validated_at: Optional[datetime] = None


class ExportLabel(BaseModel):
    image_id: UUID
    label: str
    validated: bool
    validations: List[ExportLabelValidation] = []


class ExportImage(BaseModel):
    id: UUID
    team_id: UUID
    team_name: str
    author_id: str
    author_name: Optional[str] = None
    filepath: str
    original_filename: Optional[str] = None
    label: Optional[str] = None
    status: str
    device: Optional[str] = None
    time: Optional[datetime] = None
    image_hash: str
    old_size_mb: Optional[float] = None
    old_width: Optional[float] = None
    old_height: Optional[float] = None


class ExportMetadata(BaseModel):
    image_id: UUID
    gps_info: Optional[str] = None
    make: Optional[str] = None
    camera_model: Optional[str] = None
    software: Optional[str] = None
    orientation: Optional[float] = None
    date_time: Optional[datetime] = None
    image_width: Optional[float] = None
    image_length: Optional[float] = None
    resolution_unit: Optional[str] = None
    x_resolution: Optional[float] = None
    y_resolution: Optional[float] = None
    new_width: Optional[float] = None
    new_height: Optional[float] = None
    new_size_mb: Optional[float] = None
    original_resolution: Optional[str] = None
    new_resolution: Optional[str] = None
    resizing_method: Optional[str] = None
    format_change: Optional[str] = None
    english_name: Optional[str] = None
    scientific_name: Optional[str] = None
    extra_subfolder: Optional[str] = None


class ExportResponse(BaseModel):
    type: str
    phase: str
    phase_label: str
    images: List[ExportImage]
    labels: List[ExportLabel]
    metadata: Optional[List[ExportMetadata]] = None
    total_images: int
    total_teams: int
    exported_at: datetime
