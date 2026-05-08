from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel

from app.models.model_enums import EvaluationProtocol


class ScheduleEvaluationRequest(BaseModel):
    protocol: EvaluationProtocol
    folds: Optional[int] = None


class EvaluationJobResponse(BaseModel):
    id: str
    model_id: str
    competition_id: str
    protocol: str
    status: str
    total_folds: int
    completed_folds: int
    retry_count: int
    max_retries: int
    created_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class EvaluationStatusResponse(BaseModel):
    id: str
    model_id: str
    status: str
    total_folds: int
    completed_folds: int
    progress: float
    created_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class FoldResultResponse(BaseModel):
    fold_number: int
    accuracy: float
    precision: float
    recall: float
    f1_score: float
    confusion_matrix: Optional[List[List[int]]] = None
    execution_time_seconds: Optional[float] = None


class EvaluationResultsResponse(BaseModel):
    evaluation_id: str
    model_id: str
    status: str
    total_folds: int
    mean_accuracy: float
    std_accuracy: Optional[float] = None
    mean_precision: float
    std_precision: Optional[float] = None
    mean_recall: float
    std_recall: Optional[float] = None
    mean_f1: float
    std_f1: Optional[float] = None
    folds: List[FoldResultResponse]


class RetryEvaluationResponse(BaseModel):
    evaluation_id: str
    retry_count: int
    restarted: bool


class CompetitionEvaluationsResponse(BaseModel):
    evaluations: List[EvaluationJobResponse]


class TeamScoreEntry(BaseModel):
    team_id: str
    team_name: str
    model_id: str
    mean_accuracy: float
    protocol: str
    evaluation_id: str


class CompetitionResultsResponse(BaseModel):
    competition_id: str
    final_rankings: List[TeamScoreEntry]
