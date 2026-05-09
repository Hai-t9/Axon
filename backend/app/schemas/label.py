from pydantic import BaseModel
from uuid import UUID


class LabelBase(BaseModel):
    label: str


class LabelCreate(LabelBase):
    pass


class LabelUpdate(LabelBase):
    pass


class LabelResponse(BaseModel):
    id: int
    image_id: UUID
    label: str
    validated: bool

    class Config:
        from_attributes = True


class LabelValidationResponse(BaseModel):
    id: int
    validated: bool

    class Config:
        from_attributes = True
