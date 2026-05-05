from sqlalchemy import Column, ForeignKey, Index, Integer, JSON, String
from sqlalchemy.orm import relationship

from core.database import Base


class PhaseLog(Base):
    __tablename__ = "phase_log"

    id = Column(Integer, primary_key=True)
    competition_id = Column(Integer, ForeignKey("competition.id"), nullable=False)
    phase_dates = Column(JSON, nullable=True)
    current_phase = Column(String, nullable=False)

    competition = relationship("Competition", back_populates="phase_logs")

    __table_args__ = (
        Index("idx_phase_log_competition_id", "competition_id"),
    )
