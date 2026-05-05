from typing import List

from pydantic import BaseModel


class ValidationImage(BaseModel):
    id: int
    filepath: str


class ValidationPendingImage(ValidationImage):
    label: str


class ValidationBatchResponse(BaseModel):
    images: List[ValidationImage]


class ValidationVoteCreate(BaseModel):
    label: str


class ValidationVoteResponse(BaseModel):
    validation_id: int
    label: str


class ValidationPendingResponse(BaseModel):
    images: List[ValidationPendingImage]
    total: int
