from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class Label(Base):
    __tablename__ = "label"

    id = Column(Integer, primary_key=True)
    image_id = Column(PostgresUUID(as_uuid=True), ForeignKey("image.id"), nullable=False)
    label = Column(String, nullable=False)
    validated = Column(Boolean, nullable=False, server_default="false")

    image = relationship("Image", back_populates="labels")
    validations = relationship(
        "LabelValidation", back_populates="label_record", cascade="all, delete-orphan"
    )

    __table_args__ = (Index("idx_label_image_id", "image_id"),)


class LabelValidation(Base):
    __tablename__ = "label_validations"

    id = Column(Integer, primary_key=True)
    label_id = Column(Integer, ForeignKey("label.id"), nullable=False)
    validator_id = Column(
        PostgresUUID(as_uuid=True), ForeignKey("user.id"), nullable=False
    )
    label = Column(String, nullable=False)
    validated_at = Column(DateTime, server_default=func.now())

    label_record = relationship("Label", back_populates="validations")
    validator = relationship("User", back_populates="label_validations")

    __table_args__ = (Index("idx_label_validations_label_id", "label_id"),)
