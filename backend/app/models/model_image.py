from sqlalchemy import Column, DateTime, Float, ForeignKey, Index, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from core.database import Base
from .model_enums import image_status_enum


class Image(Base):
    __tablename__ = "image"

    id = Column(Integer, primary_key=True)
    team_id = Column(Integer, ForeignKey("team.id"), nullable=False)
    author_id = Column(Integer, ForeignKey("user.id"), nullable=False)
    time = Column(DateTime, server_default=func.now())
    label = Column(String, nullable=True)
    filepath = Column(String, unique=True, nullable=False)
    status = Column(image_status_enum, nullable=False, server_default="onhold")
    original_filename = Column(String, nullable=True)
    old_extension = Column(String, nullable=True)
    image_hash = Column(String, unique=True, nullable=False)
    old_size_mb = Column(Float, nullable=True)
    old_width = Column(Float, nullable=True)
    old_height = Column(Float, nullable=True)
    device = Column(String, nullable=True)

    team = relationship("Team", back_populates="images")
    author = relationship("User", back_populates="images_authored")
    metadata_entry = relationship(
        "ImageMetadata", back_populates="image", uselist=False, cascade="all, delete-orphan"
    )
    labels = relationship("Label", back_populates="image", cascade="all, delete-orphan")

    __table_args__ = (
        Index("idx_image_team_id", "team_id"),
        Index("idx_image_author_id", "author_id"),
    )


class ImageMetadata(Base):
    __tablename__ = "image_metadata"

    id = Column(Integer, primary_key=True)
    image_id = Column(Integer, ForeignKey("image.id"), unique=True, nullable=False)
    gps_info = Column("GPSInfo", String, nullable=True)
    image_width = Column("ImageWidth", Float, nullable=True)
    image_length = Column("ImageLength", Float, nullable=True)
    resolution_unit = Column("ResolutionUnit", String, nullable=True)
    exif_offset = Column("ExifOffset", Float, nullable=True)
    make = Column("Make", String, nullable=True)
    camera_model = Column("Model", String, nullable=True)
    software = Column("Software", String, nullable=True)
    orientation = Column("Orientation", Float, nullable=True)
    date_time = Column("DateTime", DateTime, nullable=True)
    ycbcr_positioning = Column("YCbCrPositioning", String, nullable=True)
    x_resolution = Column("XResolution", Float, nullable=True)
    y_resolution = Column("YResolution", Float, nullable=True)
    new_width = Column(Float, nullable=True)
    new_height = Column(Float, nullable=True)
    new_size_mb = Column(Float, nullable=True)
    extra_subfolder = Column(String, nullable=True)
    original_resolution = Column(String, nullable=True)
    new_resolution = Column(String, nullable=True)
    resizing_method = Column(String, nullable=True)
    format_change = Column(String, nullable=True)
    label = Column(String, nullable=True)
    english_name = Column(String, nullable=True)
    scientific_name = Column(String, nullable=True)

    image = relationship("Image", back_populates="metadata_entry")
