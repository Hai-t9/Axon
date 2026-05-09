from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel


class LeaderboardTeam(BaseModel):
    id: UUID
    name: str

    class Config:
        from_attributes = True


class LeaderboardEntry(BaseModel):
    rank: int
    team: LeaderboardTeam
    score: float
    submitted_at: Optional[datetime] = None
    models_submitted: int = 0
    accuracy: Optional[float] = None
    precision: Optional[float] = None
    recall: Optional[float] = None
    f1_score: Optional[float] = None
    protocol: Optional[str] = None

    class Config:
        from_attributes = True


class LeaderboardResponse(BaseModel):
    entries: List[LeaderboardEntry]
    total_teams: int
    type: str
    phase: str
    phase_label: str
    last_updated: datetime
