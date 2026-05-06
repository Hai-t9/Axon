"""
FILE: backend/app/schemas/model_submission.py
"""

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel


class ModelResponse(BaseModel):
    id: int
    team_id: int
    competition_id: int
    docker_img_filepath: str
    submitted_at: datetime

    class Config:
        orm_mode = True


class ModelListResponse(BaseModel):
    items: List[ModelResponse]
    total: int