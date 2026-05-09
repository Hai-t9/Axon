from uuid import UUID

from sqlalchemy.orm import Session
from sqlalchemy.orm.attributes import flag_modified

from app.models import PhaseLog


class PhaseRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_competition_id(self, competition_id: UUID) -> PhaseLog | None:
        return (
            self.db.query(PhaseLog)
            .filter(PhaseLog.competition_id == competition_id)
            .first()
        )

    def create(self, competition_id: UUID, current_phase: str, phase_dates: dict) -> PhaseLog:
        entry = PhaseLog(
            competition_id=competition_id,
            current_phase=current_phase,
            phase_dates=phase_dates,
        )
        self.db.add(entry)
        self.db.commit()
        self.db.refresh(entry)
        return entry

    def update(self, entry: PhaseLog, updates: dict) -> PhaseLog:
        for key, value in updates.items():
            setattr(entry, key, value)
            if isinstance(value, dict):
                flag_modified(entry, key)
        self.db.commit()
        self.db.refresh(entry)
        return entry

