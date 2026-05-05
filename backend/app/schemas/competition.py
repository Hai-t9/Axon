from datetime import date
from typing import List, Optional

from pydantic import BaseModel


class CompetitionConfigBase(BaseModel):
    labels: Optional[dict] = None
    data_ex: Optional[str] = None
    scoring_ex: Optional[str] = None
    overview: Optional[str] = None
    terms_conditions: Optional[str] = None
    data_md: Optional[str] = None
    data_format: Optional[str] = None
    evaluation: Optional[str] = None
    duplicate_threshhold: Optional[float] = None
    max_validations: Optional[int] = None


class CompetitionConfigResponse(CompetitionConfigBase):
    id: int
    competition_id: int

    class Config:
        orm_mode = True


class CompetitionCreate(BaseModel):
    name: str
    description: Optional[str] = None
    launch_date: Optional[date] = None
    config: Optional[CompetitionConfigBase] = None


class CompetitionUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    launch_date: Optional[date] = None
    invitation_link: Optional[str] = None


class CompetitionResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    launch_date: Optional[date] = None
    invitation_link: Optional[str] = None
    config: Optional[CompetitionConfigResponse] = None

    class Config:
        orm_mode = True


class CompetitionListResponse(BaseModel):
    items: List[CompetitionResponse]
    total: int
    page: int
    limit: int

