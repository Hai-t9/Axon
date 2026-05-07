# Model Submission Service

Handles model file uploads, validation, storage, versioning, and scheduling for the evaluation phase of competitions.

## Overview

- **Repository** (`repository.py`) — Database operations for model records and metadata
- **Service** (`service.py`) — Business logic for submission flow, validation, and scheduling
- **Controller** (`controller.py`) — FastAPI endpoints for all model submission operations

## Features

- ✅ Model format validation (TensorFlow, PyTorch, Scikit-learn, Keras, ONNX)
- ✅ Model deduplication via SHA-256 hash
- ✅ File storage with MinIO (with local fallback)
- ✅ Version tracking per team
- ✅ Metadata extraction and storage
- ✅ Automatic scheduling for evaluation
- ✅ Role-based access control

## API Endpoints

### Submit Model
```
POST /api/v1/competitions/{comp_id}/models/submit
```
Query Parameters:
- `team_id` (int) — Team submitting the model
- `model_name` (str) — Name of the model
- `framework` (str) — ML framework (tensorflow, pytorch, sklearn, keras, onnx)
- `python_version` (str) — Python version used

Body: Model file (multipart/form-data)

Returns: ModelSubmitResponse with model ID, version, status

### List Competition Models
```
GET /api/v1/competitions/{comp_id}/models
```
Query Parameters:
- `page` (int, default: 1)
- `limit` (int, default: 20, max: 100)

Returns: Paginated list of models

### Get Model Details
```
GET /api/v1/models/{model_id}
```
Returns: ModelResponse with full model and metadata details

### Schedule Model for Evaluation
```
PUT /api/v1/models/{model_id}/schedule
```
Requires: Host or Staff role

Returns: ModelScheduleResponse

### Delete Model
```
DELETE /api/v1/models/{model_id}
```
Requires: Host or Staff role

Returns: Deletion confirmation

### Get Team Model History
```
GET /api/v1/teams/{team_id}/models/history
```
Query Parameters:
- `competition_id` (int) — Competition ID
- `page` (int, default: 1)
- `limit` (int, default: 20, max: 100)

Returns: ModelHistoryResponse with all versions and status breakdown

## Submission Flow

```
1. User submits model file + metadata
   ↓
2. Validate format (extension check)
   ↓
3. Validate structure (required fields)
   ↓
4. Generate SHA-256 hash
   ↓
5. Check for duplicate (same hash)
   ↓
6. Store file in MinIO/local storage
   ↓
7. Save model record (v1, v2, etc.)
   ↓
8. Save metadata (framework, dependencies, shapes)
   ↓
9. Schedule for evaluation (status → SCHEDULED)
   ↓
10. Return submission confirmation
```

## Model Versions

Each team submission increments the version counter:
- v1: First submission
- v2: Second submission (replaces v1 in eval, but history is kept)
- v3: Third submission, etc.

All versions are stored and can be retrieved via the history endpoint.

## Supported Formats

| Format | Extensions | Use Case |
|--------|-----------|----------|
| TensorFlow | .pb, .h5, .zip | Production models, keras integration |
| PyTorch | .pt, .pth, .zip | Deep learning models |
| Scikit-learn | .pkl, .pickle | Traditional ML |
| Keras | .h5, .zip | Neural networks |
| ONNX | .onnx | Interoperable format |

## Validation Rules

### Format Validation
- File extension must match supported formats
- Raises `ValidationError` if unsupported

### Structure Validation
- `model_name` (required) — string
- `framework` (required) — one of supported frameworks
- `python_version` (required) — string (e.g., "3.9")
- `framework_version` (optional) — string
- `dependencies` (optional) — list of pip packages
- `input_shape` (optional) — shape string
- `output_shape` (optional) — shape string
- `training_dataset` (optional) — dataset description

### Deduplication
Models with identical file content (same SHA-256 hash) are rejected to prevent re-submissions of unchanged models.

## Database Models

### Model
```python
id: UUID
team_id: int (FK)
competition_id: int (FK)
submitted_by: int (FK to User)
filename: str
storage_path: str (S3/MinIO path)
model_hash: str (SHA-256)
format: enum (tensorflow | pytorch | sklearn | keras | onnx)
framework_version: str
size_mb: float
status: enum (received | validated | scheduled | queued | evaluating | completed)
version: int (per team)
submitted_at: datetime
scheduled_at: datetime (nullable)
```

### ModelMetadata
```python
id: int
model_id: UUID (FK)
model_name: str
description: str (nullable)
framework: str
framework_version: str (nullable)
python_version: str
dependencies: JSON (list of strings, nullable)
input_shape: str (nullable)
output_shape: str (nullable)
training_dataset: str (nullable)
performance_metrics: JSON (optional metrics)
created_at: datetime
```

## Error Handling

### HTTP 400 Bad Request
- Empty file
- Unsupported format
- Missing required metadata
- Duplicate model hash
- Invalid model state for operation

### HTTP 401 Unauthorized
- Missing authorization header
- Invalid token

### HTTP 403 Forbidden
- User not a participant in competition
- User lacks required role

### HTTP 404 Not Found
- Model not found
- Team not found

### HTTP 501 Not Implemented
- `/teams/{team_id}/models` endpoint (requires team→comp lookup improvement)

## Future Enhancements

- [ ] Model signature validation (load and test locally)
- [ ] Dependency resolution check (pip install validation)
- [ ] Input/output shape validation against dataset specs
- [ ] S3 presigned URLs for model downloads
- [ ] Model comparison/diff between versions
- [ ] Automatic model pruning after evaluation
- [ ] Webhook notifications on submission events
