from sqlalchemy import Column, DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from core.database import Base
from .model_enums import role_type_enum


class User(Base):
    __tablename__ = "user"

    id = Column(Integer, primary_key=True)
    fullname = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)
    password = Column(String, nullable=False)
    phone = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    roles = relationship("Role", back_populates="user", cascade="all, delete-orphan")
    images_authored = relationship("Image", back_populates="author")
    label_validations = relationship("LabelValidation", back_populates="validator")


class Role(Base):
    __tablename__ = "role"

    user_id = Column(Integer, ForeignKey("user.id"), primary_key=True)
    competition_id = Column(Integer, ForeignKey("competition.id"), primary_key=True)
    role = Column(role_type_enum, nullable=False)

    user = relationship("User", back_populates="roles")
    competition = relationship("Competition", back_populates="roles")

    __table_args__ = (
        Index("idx_role_user_id", "user_id"),
        Index("idx_role_competition_id", "competition_id"),
    )
