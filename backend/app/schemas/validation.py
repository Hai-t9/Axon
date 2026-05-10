from pydantic import BaseModel


class ValidationImage(BaseModel):
    image_id: str
    filepath: str
    current_label: str


class ValidationPendingImage(BaseModel):
    id: str
    filepath: str
    label: str


class ValidationListResponse(BaseModel):
    images: list[ValidationImage]
    total: int


class ValidationVoteCreate(BaseModel):
    label: str


class ValidationVoteResponse(BaseModel):
    validation_id: str
    label: str


class ValidationPendingResponse(BaseModel):
    images: list[ValidationPendingImage]
    total: int
