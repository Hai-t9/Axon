from datetime import datetime
from typing import List

from pydantic import BaseModel



class LeaderboardMember(BaseModel):
    id: int
    name: str
    link: str

class LeaderboardTeam(BaseModel):
    id: int
    name: str
    members: List[LeaderboardMember] = []

    class Config:
        orm_mode = True


class LeaderboardEntry(BaseModel):
    rank: int
    team: LeaderboardTeam
    score: float
    submitted_at: datetime

    class Config:
        orm_mode = True


class LeaderboardResponse(BaseModel):
    entries: List[LeaderboardEntry]
    total_teams: int
    last_updated: datetime
