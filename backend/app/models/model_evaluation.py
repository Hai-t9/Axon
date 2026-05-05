from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class Evaluation(Base):
    __tablename__ = "evaluation"

    id = Column(Integer, primary_key=True)
    model_id = Column(Integer, ForeignKey("model.id"), unique=True, nullable=False)
    score = Column(Float, nullable=False)
    evaluated_at = Column(DateTime, server_default=func.now())

    model = relationship("Model", back_populates="evaluation")

