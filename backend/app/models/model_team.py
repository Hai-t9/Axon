from sqlalchemy import Column, ForeignKey, Integer, JSON, String, UniqueConstraint
from sqlalchemy.orm import relationship

from app.core.database import Base


class Team(Base):
    __tablename__ = "team"

    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    comp_id = Column(Integer, ForeignKey("competition.id"), nullable=False)
    user_ids = Column(JSON, nullable=True)

    competition = relationship("Competition", back_populates="teams")
    images = relationship("Image", back_populates="team", cascade="all, delete-orphan")
    dataset = relationship("Dataset", back_populates="team", uselist=False, cascade="all, delete-orphan")
    models = relationship("Model", back_populates="team", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("name", "comp_id", name="uq_team_name_comp_id"),
    )

