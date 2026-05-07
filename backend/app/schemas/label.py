from pydantic import BaseModel


class LabelBase(BaseModel):
    label: str


class LabelCreate(LabelBase):
    pass


class LabelUpdate(LabelBase):
    pass


class LabelResponse(BaseModel):
    id: int
    image_id: int
    label: str
    validated: bool

    class Config:
        from_attributes = True


class LabelValidationResponse(BaseModel):
    id: int
    validated: bool

    class Config:
        from_attributes = True
