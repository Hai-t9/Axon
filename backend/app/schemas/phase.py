from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel


class PhaseResponse(BaseModel):
    competition_id: UUID
    current_phase: str
    phase_dates: Dict[str, Any]

    class Config:
        from_attributes = True


class PhaseAdvanceResponse(BaseModel):
    current_phase: str
    previous_phase: str
    transitioned_at: datetime


class PhaseOverrideRequest(BaseModel):
    target_phase: str
    reason: Optional[str] = None


class PhaseDeadlineRequest(BaseModel):
    new_deadline: datetime


class PhaseTransitionModeRequest(BaseModel):
    mode: str


class PhaseTimelineResponse(BaseModel):
    phases: List[Dict[str, Any]]
    total: int


class PhaseHistoryResponse(BaseModel):
    audit_logs: List[Dict[str, Any]]
    total: int


class PhaseValidateRequest(BaseModel):
    target_phase: str


class PhaseValidationResponse(BaseModel):
    valid: bool
    message: str
