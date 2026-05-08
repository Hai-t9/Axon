from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class Evaluation(Base):
    __tablename__ = "evaluation"

    id = Column(Integer, primary_key=True)
    model_id = Column(Integer, ForeignKey("model.id"), nullable=False)
    score = Column(Float, nullable=True)
    metrics_json = Column(String, nullable=True)
    status = Column(String, nullable=False, default="pending")
    evaluated_at = Column(DateTime, server_default=func.now())

    model = relationship("Model", back_populates="evaluation")

