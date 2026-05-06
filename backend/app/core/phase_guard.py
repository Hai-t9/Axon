"""
FILE: backend/app/core/phase_guard.py

Reusable FastAPI dependencies that enforce competition phase restrictions.

Usage in controllers:
    from app.core.phase_guard import require_phase

    @router.post("/images")
    async def upload(
        comp_id: int,
        _: None = Depends(require_phase(comp_id_param="comp_id", allowed=["active"])),
    ):
        ...

Or more practically, call the service helper directly inside a route:
    phase_guard.assert_phase(db, competition_id, allowed=["active"])
"""

from typing import List

from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.core.exceptions import ValidationError
from app.models import PhaseLog


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


class PhaseGuard:
    """
    Service-layer helper for asserting that a competition is in an
    allowed phase before executing an operation.

    Call ``assert_phase`` inside any service method that should be
    phase-restricted.  It raises ``ValidationError`` (which controllers
    translate to HTTP 400) when the current phase is not in
    ``allowed_phases``.
    """

    # Canonical phase order — used for human-readable error messages.
    PHASE_ORDER = ["creation", "active", "evaluation", "complete"]

    # Human-readable descriptions shown in error messages.
    PHASE_LABELS = {
        "creation": "Competition Setup (Phase 1)",
        "active": "Data Collection (Phase 2)",
        "evaluation": "Model Evaluation (Phase 3)",
        "complete": "Competition Complete (Phase 4)",
    }

    def assert_phase(
        self,
        db: Session,
        competition_id: int,
        allowed_phases: List[str],
        action_description: str = "this action",
    ) -> PhaseLog:
        """
        Assert that the competition is currently in one of
        ``allowed_phases``.

        Returns the PhaseLog row so callers can inspect phase_dates
        without a second DB hit.

        Raises ``ValidationError`` if the phase is wrong.
        """
        phase_log = (
            db.query(PhaseLog)
            .filter(PhaseLog.competition_id == competition_id)
            .first()
        )

        if not phase_log:
            # No phase log → treat as "creation" phase.
            current_phase = "creation"
        else:
            current_phase = phase_log.current_phase

        if current_phase not in allowed_phases:
            allowed_labels = " or ".join(
                self.PHASE_LABELS.get(p, p) for p in allowed_phases
            )
            current_label = self.PHASE_LABELS.get(current_phase, current_phase)
            raise ValidationError(
                f"'{action_description}' is only allowed during: {allowed_labels}. "
                f"The competition is currently in: {current_label}."
            )

        return phase_log

    def get_current_phase(self, db: Session, competition_id: int) -> str:
        """Return the current phase string, defaulting to 'creation'."""
        phase_log = (
            db.query(PhaseLog)
            .filter(PhaseLog.competition_id == competition_id)
            .first()
        )
        return phase_log.current_phase if phase_log else "creation"


# Singleton — import and use this everywhere.
phase_guard = PhaseGuard()