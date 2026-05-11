from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class UserResponse(BaseModel):
    id: UUID | int | str
    fullname: str
    email: EmailStr
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    full_name: Optional[str] = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class SignupResponse(BaseModel):
    message: str
    email: str
    verification_sent: bool


class VerifyTokenRequest(BaseModel):
    access_token: str


class VerifyTokenResponse(BaseModel):
    message: str
    verified: bool


class ResendVerificationRequest(BaseModel):
    email: EmailStr


class ResendVerificationResponse(BaseModel):
    message: str
    sent: bool
