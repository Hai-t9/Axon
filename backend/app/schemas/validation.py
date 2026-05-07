from pydantic import BaseModel


class ValidationImage(BaseModel):
    id: int
    filepath: str


class ValidationPendingImage(ValidationImage):
    label: str


class ValidationNextResponse(ValidationImage):
    pass


class ValidationVoteCreate(BaseModel):
    label: str


class ValidationVoteResponse(BaseModel):
    validation_id: int
    label: str


class ValidationPendingResponse(BaseModel):
    images: list[ValidationPendingImage]
    total: int
