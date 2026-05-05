from typing import List, Optional

from pydantic import BaseModel

from .user import UserResponse


class TeamCreate(BaseModel):
    name: str
    user_ids: Optional[List[int]] = None


class TeamUpdate(BaseModel):
    name: Optional[str] = None
    user_ids: Optional[List[int]] = None


class TeamResponse(BaseModel):
    id: int
    name: str
    comp_id: int
    user_ids: Optional[List[int]] = None

    class Config:
        orm_mode = True


class TeamListResponse(BaseModel):
    items: List[TeamResponse]
    total: int
    page: int
    limit: int


class TeamMemberAddRequest(BaseModel):
    user_id: int


class TeamMembersResponse(BaseModel):
    members: List[UserResponse]
    total: int


class TeamStatisticsResponse(BaseModel):
    total_members: int
    images_uploaded: int
    models_submitted: int

