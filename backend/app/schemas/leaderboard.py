from datetime import datetime
from typing import List
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
    submitted_at: datetime

    class Config:
        from_attributes = True


class LeaderboardResponse(BaseModel):
    entries: List[LeaderboardEntry]
    total_teams: int
    last_updated: datetime
