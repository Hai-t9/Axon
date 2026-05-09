from typing import Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel

from .user import UserResponse


class TeamCreate(BaseModel):
    name: str
    user_emails: Optional[Dict[str, bool]] = None


class TeamUpdate(BaseModel):
    name: Optional[str] = None
    user_emails: Optional[Dict[str, bool]] = None


class TeamResponse(BaseModel):
    id: UUID
    name: str
    comp_id: UUID
    user_emails: Optional[Dict[str, bool]] = None

    class Config:
        from_attributes = True


class TeamListResponse(BaseModel):
    items: List[TeamResponse]
    total: int
    page: int
    limit: int


class TeamMembersResponse(BaseModel):
    members: List[UserResponse]
    total: int


class MemberStats(BaseModel):
    user_id: UUID
    name: str
    email: str
    images_uploaded: int
    images_validated: int

class TeamStatisticsResponse(BaseModel):
    total_members: int
    images_uploaded: int
    models_submitted: int
    members: Optional[List[MemberStats]] = None
