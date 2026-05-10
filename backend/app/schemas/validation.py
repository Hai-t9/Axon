from pydantic import BaseModel


class ValidationImage(BaseModel):
    id: str
    filepath: str


class ValidationPendingImage(ValidationImage):
    label: str


class ValidationListResponse(BaseModel):
    image_ids: list[str]


class ValidationVoteCreate(BaseModel):
    label: str


class ValidationVoteResponse(BaseModel):
    validation_id: int
    label: str


class ValidationPendingResponse(BaseModel):
    images: list[ValidationPendingImage]
    total: int
