from pydantic import BaseModel
from typing import Optional
from datetime import datetime

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

class ImageResponse(ImageBase):
    id: int
    team_id: int
    author_id: int
    time: datetime
    label: Optional[str] = None
    metadata_rel: Optional[ImageMetadataBase] = None

    class Config:
        from_attributes = True
