from sqlalchemy import Column, DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class Model(Base):
    __tablename__ = "model"

    id = Column(Integer, primary_key=True)
    team_id = Column(Integer, ForeignKey("team.id"), nullable=False)
    competition_id = Column(Integer, ForeignKey("competition.id"), nullable=False)
    docker_img_filepath = Column(String, nullable=False)
    model_hash = Column(String, nullable=True)  # SHA-256 for dedup
    submitted_at = Column(DateTime, server_default=func.now())

    team = relationship("Team", back_populates="models")
    competition = relationship("Competition", back_populates="models")
    evaluations = relationship(
        "Evaluation", back_populates="model", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("idx_model_team_id", "team_id"),
        Index("idx_model_competition_id", "competition_id"),
    )

