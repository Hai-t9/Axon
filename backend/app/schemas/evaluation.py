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
    id: int
    model_id: int
    score: Optional[float] = None
    metrics_json: Optional[str] = None
    status: str
    evaluated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class EvaluationListResponse(BaseModel):
    items: list[EvaluationResultResponse]
