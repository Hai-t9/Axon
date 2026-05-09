from sqlalchemy import Column, ForeignKey, Index, Integer, String
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import relationship

from app.core.database import Base


class PhaseLog(Base):
    __tablename__ = "phase_log"

    id = Column(Integer, primary_key=True, autoincrement=True)
    competition_id = Column(
        PostgresUUID(as_uuid=True), ForeignKey("competition.id"), nullable=False
    )
    phase_dates = Column(JSON, nullable=True)  # JSONB in database
    current_phase = Column(String, nullable=False)

    competition = relationship("Competition", back_populates="phase_logs")

    __table_args__ = (Index("idx_phase_log_competition_id", "competition_id"),)
