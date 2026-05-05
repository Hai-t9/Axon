from datetime import datetime
from typing import Any, Dict, List

from app.core.exceptions import NotFoundError, ValidationError

from .repository import PhaseRepository

_PHASE_ORDER = ["creation", "active", "evaluation", "complete"]


class PhaseService:
    def __init__(self, repository: PhaseRepository):
        self.repository = repository

    def _now_iso(self) -> str:
        return datetime.utcnow().isoformat()

    def _ensure_phase_dates(self, phase_dates: Dict[str, Any] | None) -> Dict[str, Any]:
        if isinstance(phase_dates, dict):
            return phase_dates
        return {}

    def _ensure_phase_log(self, competition_id: int):
        entry = self.repository.get_by_competition_id(competition_id)
        if entry:
            return entry

        phase_dates = {
            "transition_mode": "manual",
            "deadlines": {},
            "timeline": [
                {
                    "phase": "creation",
                    "start": self._now_iso(),
                    "deadline": None,
                    "status": "in_progress",
                }
            ],
            "history": [],
        }
        return self.repository.create(competition_id, "creation", phase_dates)

    def _record_history(
        self,
        phase_dates: Dict[str, Any],
        action: str,
        from_phase: str | None,
        to_phase: str | None,
        performed_by: int,
        details: Dict[str, Any] | None = None,
    ) -> None:
        history = phase_dates.setdefault("history", [])
        history.append(
            {
                "action": action,
                "from_phase": from_phase,
                "to_phase": to_phase,
                "performed_by": performed_by,
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

    def get_current_phase(self, competition_id: int):
        entry = self._ensure_phase_log(competition_id)
        return entry

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

    def advance_phase(self, competition_id: int, user_id: int) -> dict:
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

    def override_phase(
        self, competition_id: int, target_phase: str, reason: str | None, user_id: int
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

    def adjust_phase_deadline(self, competition_id: int, new_deadline: datetime, user_id: int):
        if new_deadline <= datetime.utcnow():
            raise ValidationError("Deadline must be in the future")

        entry = self._ensure_phase_log(competition_id)
        phase_dates = self._ensure_phase_dates(entry.phase_dates)
        deadlines = phase_dates.setdefault("deadlines", {})
        current_phase = entry.current_phase

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

    def set_transition_mode(self, competition_id: int, mode: str, user_id: int):
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

    def get_timeline(self, competition_id: int) -> List[Dict[str, Any]]:
        entry = self._ensure_phase_log(competition_id)
        phase_dates = self._ensure_phase_dates(entry.phase_dates)
        return phase_dates.get("timeline", [])

    def get_history(self, competition_id: int) -> List[Dict[str, Any]]:
        entry = self._ensure_phase_log(competition_id)
        phase_dates = self._ensure_phase_dates(entry.phase_dates)
        return phase_dates.get("history", [])

