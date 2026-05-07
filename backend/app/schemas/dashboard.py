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


class DashboardParticipantConfig(BaseModel):
    labels: dict | None = None
    data_ex: str | None = None
    overview: str | None = None
    terms_conditions: str | None = None
    data_md: str | None = None
    data_format: str | None = None


class DashboardParticipantResponse(BaseModel):
    phase_info: PhaseResponse
    config: DashboardParticipantConfig
    image_stats: DashboardImageStats
    team_info: TeamResponse


class DashboardCachedResponse(BaseModel):
    cached_at: str
    data: DashboardResponse


class DashboardCacheClearResponse(BaseModel):
    cleared: bool
