from typing import Any, Dict, List, Optional

from pydantic import BaseModel

from .competition import CompetitionConfigResponse
from .phase import PhaseResponse
from .team import TeamResponse


class DashboardImageStats(BaseModel):
    total: int
    verified: int
    on_hold: int


class LocationMetadata(BaseModel):
    image_id: Any
    gps_info: Optional[str] = None
    location_metadata: Optional[Dict[str, Any]] = None


class DashboardTeamInfo(BaseModel):
    items: List[TeamResponse]
    total: int


class DashboardResponse(BaseModel):
    phase_info: PhaseResponse
    config: CompetitionConfigResponse
    image_stats: DashboardImageStats
    team_info: DashboardTeamInfo
    device_stats: Dict[str, int]
    label_distribution: Dict[str, int]
    locations: List[LocationMetadata]


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
    device_stats: Dict[str, int]
    label_distribution: Dict[str, int]
    locations: List[LocationMetadata]


class DashboardCachedResponse(BaseModel):
    cached_at: str
    data: DashboardResponse


class DashboardCacheClearResponse(BaseModel):
    cleared: bool
