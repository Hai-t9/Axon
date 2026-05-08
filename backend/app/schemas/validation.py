from typing import List

from pydantic import BaseModel


class ValidationImage(BaseModel):
    id: int
    filepath: str
    current_label: str | None = None


class ValidationPendingImage(ValidationImage):
    label: str


class ValidationNextResponse(BaseModel):
    image: ValidationImage | None


class ValidationVoteCreate(BaseModel):
    label: str


class ValidationVoteResponse(BaseModel):
    validation_id: int
    label: str


class ValidationPendingResponse(BaseModel):
    images: List[ValidationPendingImage]
    total: int
