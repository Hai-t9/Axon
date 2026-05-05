from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Enum
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base

class Image(Base):
    __tablename__ = "images"

    id = Column(Integer, primary_key=True, index=True)
    team_id = Column(Integer, index=True)
    author_id = Column(Integer, index=True)
    time = Column(DateTime, default=datetime.utcnow)
    label = Column(String, nullable=True)
    filepath = Column(String, nullable=False)
    status = Column(String, default="onhold")
    original_filename = Column(String, nullable=True)
    old_extension = Column(String, nullable=True)
    image_hash = Column(String, nullable=True)
    old_size_mb = Column(Float, default=0.0)
    old_width = Column(Float, default=0.0)
    old_height = Column(Float, default=0.0)
    device = Column(String, default="Unknown")

    metadata_rel = relationship("ImageMetadata", back_populates="image", uselist=False)

class ImageMetadata(Base):
    __tablename__ = "image_metadata"

    id = Column(Integer, primary_key=True, index=True)
    image_id = Column(Integer, ForeignKey("images.id"), unique=True)
    GPSInfo = Column(String, nullable=True)
    ImageWidth = Column(Float, nullable=True)
    ImageLength = Column(Float, nullable=True)
    ResolutionUnit = Column(String, nullable=True)
    Make = Column(String, nullable=True)
    Model = Column(String, nullable=True)
    Software = Column(String, nullable=True)
    Orientation = Column(Integer, nullable=True)
    DateTime = Column(DateTime, nullable=True)
    XResolution = Column(Float, nullable=True)
    YResolution = Column(Float, nullable=True)
    New_width = Column(Float, nullable=True)
    New_height = Column(Float, nullable=True)
    New_size_mb = Column(Float, nullable=True)
    Extra_subfolder = Column(String, nullable=True)
    format_change = Column(String, nullable=True)

    image = relationship("Image", back_populates="metadata_rel")
