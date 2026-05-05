from typing import List

from pydantic import BaseModel

from .competition import CompetitionConfigResponse
from .phase import PhaseResponse
from .team import TeamResponse


class DashboardImageStats(BaseModel):
    total: int
    verified: int
    on_hold: int


class DashboardTeamInfo(BaseModel):
    items: List[TeamResponse]
    total: int


class DashboardResponse(BaseModel):
    phase_info: PhaseResponse
    config: CompetitionConfigResponse
    image_stats: DashboardImageStats
    team_info: DashboardTeamInfo
