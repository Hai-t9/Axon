from datetime import datetime
from typing import Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr

from .user import UserResponse


class TeamCreate(BaseModel):
    name: str
    user_emails: Optional[Dict[str, int]] = None


class TeamUpdate(BaseModel):
    name: Optional[str] = None
    user_emails: Optional[Dict[str, int]] = None


class TeamResponse(BaseModel):
    id: UUID
    name: str
    comp_id: UUID
    user_emails: Optional[Dict[str, int]] = None

    class Config:
        from_attributes = True


class TeamListResponse(BaseModel):
    items: List[TeamResponse]
    total: int
    page: int
    limit: int


class MemberWithStatus(BaseModel):
    id: UUID | int | str
    fullname: str
    email: EmailStr
    created_at: Optional[datetime] = None
    joined: int  # 0=invited/not joined, 1=joined

    class Config:
        from_attributes = True


class TeamMembersResponse(BaseModel):
    members: List[MemberWithStatus]
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
