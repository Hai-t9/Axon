from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel

from .user import UserResponse


class TeamCreate(BaseModel):
    name: str
    user_ids: Optional[List[UUID | str]] = None


class TeamUpdate(BaseModel):
    name: Optional[str] = None
    user_ids: Optional[List[UUID | str]] = None


class TeamResponse(BaseModel):
    id: UUID | str
    name: str
    comp_id: UUID | str
    user_ids: Optional[List[UUID | str]] = None

    class Config:
        from_attributes = True


class TeamListResponse(BaseModel):
    items: List[TeamResponse]
    total: int
    page: int
    limit: int


class TeamMemberAddRequest(BaseModel):
    user_id: UUID | str


class TeamMembersResponse(BaseModel):
    members: List[UserResponse]
    total: int


class TeamStatisticsResponse(BaseModel):
    total_members: int
    images_uploaded: int
    models_submitted: int
