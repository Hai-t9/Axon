from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from uuid import UUID

class ImageMetadataBase(BaseModel):
    GPSInfo: Optional[str] = None
    ImageWidth: Optional[float] = None
    ImageLength: Optional[float] = None
    Make: Optional[str] = None
    Model: Optional[str] = None
    Software: Optional[str] = None
    Orientation: Optional[int] = None
    DateTime: Optional[datetime] = None

    class Config:
        from_attributes = True

class ImageBase(BaseModel):
    filepath: str
    image_hash: str
    status: str
    original_filename: Optional[str]
    old_size_mb: float
    old_width: float
    old_height: float
    device: str

from typing import Optional, Union

class ImageResponse(ImageBase):
    id: Union[int, UUID]
    team_id: UUID
    author_id: UUID
    time: datetime
    label: Optional[str] = None
    metadata_rel: Optional[ImageMetadataBase] = None

    class Config:
        from_attributes = True
