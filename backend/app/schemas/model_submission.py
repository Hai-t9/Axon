from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class ModelMetadataRequest(BaseModel):
    """Request schema for model metadata when submitting a model"""

    model_name: str = Field(..., description="Name of the model")
    description: Optional[str] = Field(None, description="Description of the model")
    framework: str = Field(
        ..., description="ML framework (tensorflow, pytorch, sklearn, keras, onnx)"
    )
    framework_version: Optional[str] = Field(
        None, description="Version of the framework"
    )
    python_version: str = Field(..., description="Python version used")
    dependencies: Optional[List[str]] = Field(
        None, description="List of package dependencies"
    )
    input_shape: Optional[str] = Field(None, description="Input shape specification")
    output_shape: Optional[str] = Field(None, description="Output shape specification")
    training_dataset: Optional[str] = Field(
        None, description="Description of training dataset"
    )
    performance_metrics: Optional[dict] = Field(
        None, description="Optional performance metrics"
    )


class ModelMetadataResponse(BaseModel):
    """Response schema for model metadata"""

    id: int
    model_id: UUID
    model_name: str
    description: Optional[str]
    framework: str
    framework_version: Optional[str]
    python_version: str
    dependencies: Optional[List[str]]
    input_shape: Optional[str]
    output_shape: Optional[str]
    training_dataset: Optional[str]
    performance_metrics: Optional[dict]
    created_at: datetime

    model_config = {"from_attributes": True, "populate_by_name": True}


class ModelSubmitJsonRequest(BaseModel):
    team_id: str
    model_name: str
    framework: str
    python_version: str
    framework_version: Optional[str] = None
    description: Optional[str] = None
    file_content: str  # base64-encoded zip
    filename: str


class ModelSubmitRequest(BaseModel):
    """Request schema for submitting a model"""

    metadata: ModelMetadataRequest


class ModelSubmitResponse(BaseModel):
    """Response after successful model submission"""

    id: UUID
    team_id: UUID
    competition_id: UUID
    filename: str
    format: str
    version: int
    status: str
    submitted_at: datetime
    submitted_by: UUID
    message: str = "Model submitted successfully"

    class Config:
        from_attributes = True


class ModelResponse(BaseModel):
    """Response schema for model details"""

    id: UUID
    team_id: UUID
    competition_id: UUID
    filename: str
    storage_path: str
    format: str
    framework_version: str
    size_mb: float
    status: str
    version: int
    submitted_at: datetime
    submitted_by: UUID
    scheduled_at: Optional[datetime]
    metadata: Optional[ModelMetadataResponse] = Field(None, alias="model_metadata")

    class Config:
        from_attributes = True
        populate_by_name = True


class ModelListResponse(BaseModel):
    """Response schema for listing models"""

    items: List[ModelResponse]
    total: int
    page: int
    limit: int


class ModelScheduleRequest(BaseModel):
    """Request schema for scheduling model for evaluation"""

    pass  # No additional data needed, just schedule the model


class ModelScheduleResponse(BaseModel):
    """Response after scheduling model for evaluation"""

    model_id: str
    scheduled: bool
    evaluation_status: str
    scheduled_at: datetime

    class Config:
        from_attributes = True


class ModelHistoryResponse(BaseModel):
    """Response schema for model submission history"""

    models: List[ModelResponse]
    total: int
    versions: dict = Field(description="Version count by status")

    class Config:
        from_attributes = True
