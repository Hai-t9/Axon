from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict

class EvaluationScheduleRequest(BaseModel):
    protocol: str = "standard"

class EvaluationJobResponse(BaseModel):
    model_id: int
    job_id: str
    status: str
    message: str

class EvaluationResultResponse(BaseModel):
    model_id: int
    score: float
    evaluated_at: datetime

    model_config = ConfigDict(from_attributes=True)
