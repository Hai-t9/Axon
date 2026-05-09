from datetime import datetime
from typing import Any, Dict, List
from uuid import UUID

from app.core.exceptions import NotFoundError, ValidationError

from .repository import PhaseRepository

_PHASE_ORDER = ["0", "1", "2", "3", "4", "5"]

PHASE_LABELS = {
    "0": "Awaiting Initialisation",
    "1": "Data Collection",
    "2": "Data Validation",
    "3": "Model Submission",
    "4": "Model Evaluation",
    "5": "Finale & Leaderboard",
}


class PhaseService:
    def __init__(self, repository: PhaseRepository):
        self.repository = repository

    def _now_iso(self) -> str:
        return datetime.utcnow().isoformat()

    def _ensure_phase_dates(self, phase_dates: Dict[str, Any] | None) -> Dict[str, Any]:
        if isinstance(phase_dates, dict):
            return phase_dates
        return {}

    def _ensure_phase_log(self, competition_id: UUID):
        entry = self.repository.get_by_competition_id(competition_id)
        if entry:
            return entry

        phase_dates = {
            "transition_mode": "manual",
            "deadlines": {},
            "timeline": [
                {
                    "phase": "0",
                    "start": self._now_iso(),
                    "deadline": None,
                    "status": "in_progress",
                }
            ],
            "history": [],
        }
        return self.repository.create(competition_id, "0", phase_dates)

    def _record_history(
        self,
        phase_dates: Dict[str, Any],
        action: str,
        from_phase: str | None,
        to_phase: str | None,
        performed_by: Any,
        details: Dict[str, Any] | None = None,
    ) -> None:
        history = phase_dates.setdefault("history", [])
        history.append(
            {
                "action": action,
                "from_phase": from_phase,
                "to_phase": to_phase,
                "performed_by": str(performed_by),
                "details": details or {},
                "performed_at": self._now_iso(),
            }
        )

    def _update_timeline(
        self, phase_dates: Dict[str, Any], current_phase: str, previous_phase: str | None
    ) -> None:
        timeline = phase_dates.setdefault("timeline", [])
        if previous_phase:
            for entry in timeline:
                if entry.get("phase") == previous_phase:
                    entry["status"] = "completed"
                    break
        timeline.append(
            {
                "phase": current_phase,
                "start": self._now_iso(),
                "deadline": phase_dates.get("deadlines", {}).get(current_phase),
                "status": "in_progress",
            }
        )

    def get_current_phase(self, competition_id: UUID):
        entry = self._ensure_phase_log(competition_id)
        self._auto_advance_if_deadline_passed(entry)
        return entry

    def _auto_advance_if_deadline_passed(self, entry) -> None:
        """Advance to the next phase if the current phase's deadline has passed."""
        now = datetime.utcnow()
        for _ in range(len(_PHASE_ORDER)):
            current_phase = entry.current_phase
            phase_dates = self._ensure_phase_dates(entry.phase_dates)
            deadlines = phase_dates.get("deadlines", {}) or {}
            deadline_str = deadlines.get(current_phase)

            if not deadline_str:
                return

            deadline = datetime.fromisoformat(deadline_str)
            if deadline.tzinfo is not None:
                deadline = deadline.replace(tzinfo=None)
            if deadline > now:
                return

            current_index = _PHASE_ORDER.index(current_phase)
            if current_index >= len(_PHASE_ORDER) - 1:
                return

            next_phase = _PHASE_ORDER[current_index + 1]
            self._update_timeline(phase_dates, next_phase, current_phase)
            self._record_history(
                phase_dates,
                "auto_advance",
                current_phase,
                next_phase,
                "system",
                {"reason": "deadline_passed"},
            )
            self.repository.update(
                entry, {"current_phase": next_phase, "phase_dates": phase_dates}
            )

    def validate_phase_transition(self, current_phase: str, target_phase: str) -> dict:
        if target_phase not in _PHASE_ORDER:
            return {"valid": False, "message": "Unknown target phase"}
        if current_phase not in _PHASE_ORDER:
            return {"valid": False, "message": "Unknown current phase"}

        current_index = _PHASE_ORDER.index(current_phase)
        target_index = _PHASE_ORDER.index(target_phase)
        if target_index != current_index + 1:
            return {"valid": False, "message": "Invalid phase transition"}
        return {"valid": True, "message": "Transition allowed"}

    def advance_phase(self, competition_id: UUID, user_id: int) -> dict:
        entry = self._ensure_phase_log(competition_id)
        current_phase = entry.current_phase

        if current_phase not in _PHASE_ORDER:
            raise ValidationError("Unknown current phase")

        current_index = _PHASE_ORDER.index(current_phase)
        if current_index >= len(_PHASE_ORDER) - 1:
            raise ValidationError("Competition already in final phase")

        next_phase = _PHASE_ORDER[current_index + 1]
        validation = self.validate_phase_transition(current_phase, next_phase)
        if not validation["valid"]:
            raise ValidationError(validation["message"])

        phase_dates = self._ensure_phase_dates(entry.phase_dates)
        self._update_timeline(phase_dates, next_phase, current_phase)
        self._record_history(
            phase_dates,
            "advance",
            current_phase,
            next_phase,
            user_id,
        )

        self.repository.update(
            entry, {"current_phase": next_phase, "phase_dates": phase_dates}
        )

        return {
            "current_phase": next_phase,
            "previous_phase": current_phase,
            "transitioned_at": datetime.utcnow(),
        }

    def decrement_phase(self, competition_id: UUID, user_id: int) -> dict:
        entry = self._ensure_phase_log(competition_id)
        current_phase = entry.current_phase

        if current_phase not in _PHASE_ORDER:
            raise ValidationError("Unknown current phase")

        current_index = _PHASE_ORDER.index(current_phase)
        if current_index <= 0:
            raise ValidationError("Competition already in initial phase")

        prev_phase = _PHASE_ORDER[current_index - 1]
        phase_dates = self._ensure_phase_dates(entry.phase_dates)

        # Mark current phase timeline entry as rolled back
        timeline = phase_dates.setdefault("timeline", [])
        for entry_ in timeline:
            if entry_.get("phase") == current_phase:
                entry_["status"] = "rolled_back"
            if entry_.get("phase") == prev_phase:
                entry_["status"] = "in_progress"
                entry_["deadline"] = phase_dates.get("deadlines", {}).get(prev_phase)

        self._record_history(
            phase_dates,
            "decrement",
            current_phase,
            prev_phase,
            user_id,
        )

        self.repository.update(
            entry, {"current_phase": prev_phase, "phase_dates": phase_dates}
        )

        return {
            "current_phase": prev_phase,
            "previous_phase": current_phase,
            "transitioned_at": datetime.utcnow(),
        }

    def override_phase(
        self, competition_id: UUID, target_phase: str, reason: str | None, user_id: int
    ) -> dict:
        if target_phase not in _PHASE_ORDER:
            raise ValidationError("Unknown target phase")

        entry = self._ensure_phase_log(competition_id)
        current_phase = entry.current_phase
        phase_dates = self._ensure_phase_dates(entry.phase_dates)

        self._update_timeline(phase_dates, target_phase, current_phase)
        self._record_history(
            phase_dates,
            "override",
            current_phase,
            target_phase,
            user_id,
            {"reason": reason} if reason else None,
        )

        self.repository.update(
            entry, {"current_phase": target_phase, "phase_dates": phase_dates}
        )

        return {
            "current_phase": target_phase,
            "override_reason": reason,
            "transitioned_at": datetime.utcnow(),
        }

    def adjust_phase_deadline(self, competition_id: UUID, new_deadline: datetime, user_id: int):
        # Strip timezone info — the system uses naive UTC datetimes
        if new_deadline.tzinfo is not None:
            new_deadline = new_deadline.replace(tzinfo=None)
        if new_deadline <= datetime.utcnow():
            raise ValidationError("Deadline must be in the future")

        entry = self._ensure_phase_log(competition_id)
        current_phase = entry.current_phase
        if current_phase == "5":
            raise ValidationError("Cannot set deadline for the final phase")

        phase_dates = self._ensure_phase_dates(entry.phase_dates)
        deadlines = phase_dates.setdefault("deadlines", {})

        # Deadlines are stored inside phase_dates JSON for auditability.
        deadlines[current_phase] = new_deadline.isoformat()
        self._record_history(
            phase_dates,
            "deadline_adjustment",
            current_phase,
            None,
            user_id,
            {"new_deadline": new_deadline.isoformat()},
        )

        self.repository.update(entry, {"phase_dates": phase_dates})

        return {
            "phase": current_phase,
            "old_deadline": None,
            "new_deadline": new_deadline,
            "adjusted_at": datetime.utcnow(),
        }

    def set_transition_mode(self, competition_id: UUID, mode: str, user_id: int):
        if mode not in {"auto", "manual"}:
            raise ValidationError("Transition mode must be 'auto' or 'manual'")

        entry = self._ensure_phase_log(competition_id)
        phase_dates = self._ensure_phase_dates(entry.phase_dates)
        phase_dates["transition_mode"] = mode
        self._record_history(
            phase_dates,
            "transition_mode_changed",
            entry.current_phase,
            None,
            user_id,
            {"mode": mode},
        )

        self.repository.update(entry, {"phase_dates": phase_dates})
        return {"competition_id": competition_id, "transition_mode": mode}

    def get_timeline(self, competition_id: UUID) -> List[Dict[str, Any]]:
        entry = self._ensure_phase_log(competition_id)
        phase_dates = self._ensure_phase_dates(entry.phase_dates)
        return phase_dates.get("timeline", [])

    def get_history(self, competition_id: UUID) -> List[Dict[str, Any]]:
        entry = self._ensure_phase_log(competition_id)
        phase_dates = self._ensure_phase_dates(entry.phase_dates)
        return phase_dates.get("history", [])

