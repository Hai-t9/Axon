---
sidebar_position: 10
---

# Model Submission

## Overview

Handles participant model submissions during the evaluation phase. Participants submit a **Docker build context** (`.zip` file) containing their model and inference code. The system validates the submission against organizer-defined requirements, stores models with versioning, tracks submission metadata, and schedules models for evaluation.

**Key Innovation**: Instead of raw model files, participants submit a complete, reproducible Docker environment that ensures consistency during evaluation.

---

## Architecture

### Submission Format

Participants upload a `.zip` Docker build context with this mandatory structure:

```
submission.zip/
├── Dockerfile           ← (required) Builds the container image
├── inference.py         ← (required) Contains prediction function
├── requirements.txt     ← (required) Python dependencies
├── model/               ← (required) Directory with model file
│   └── model.pt        ← (one of: .pt, .pth, .pkl, .h5, .onnx)
└── data/               ← (required, empty) Where dataset is injected at evaluation
```

### Organizer Configuration

Organizers define submission requirements via the `config.model_spec` JSON field:

```json
{
  "required_files": ["Dockerfile", "inference.py", "requirements.txt"],
  "model_dir": "model",
  "data_dir": "data",
  "inference_function": "predict",
  "allowed_model_formats": ["pytorch", "tensorflow", "sklearn"],
  "required_packages": ["numpy", "torch"],
  "max_size_mb": 500.0,
  "python_version_min": "3.9"
}
```

---

## Responsibility

1. **Validate** Docker submissions against organizer's `model_spec`
2. **Check eligibility**: Team exists, belongs to competition, user is a member
3. **Check phase**: Only accept submissions during `evaluation` phase
4. **Deduplicate**: Reject models with identical SHA-256 hashes (app-level)
5. **Version**: Auto-increment version per team per competition
6. **Store**: Upload zip to MinIO (or local fallback)
7. **Schedule**: Auto-schedule validated models for evaluation

---

## Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `submitModel` | `teamId`, `modelZip`, `metadata` | `{ id, team_id, version, format, status }` |
| `validateDockerSubmission` | `zipBytes`, `spec` | `{ valid, detected_format }` |
| `getTeamModelHistory` | `teamId`, `compId` | `{ models[], total, versions }` |
| `getModelById` | `modelId` | `{ id, team_id, metadata, status }` |
| `scheduleModelForEvaluation` | `modelId` | `{ model_id, scheduled, evaluation_status }` |

---

## APIs

### Endpoints

#### Submit Model
```
POST /api/v1/competitions/{comp_id}/models/submit
```
**Headers**: `Authorization: Bearer <token>`

**Query Parameters**:
- `team_id` (UUID) — Team submitting
- `model_name` (str) — Human-readable name
- `framework` (str) — pytorch | tensorflow | sklearn | keras | onnx
- `python_version` (str) — e.g., 3.9
- `framework_version` (str, optional)
- `description` (str, optional)

**Body**: Multipart file upload (`.zip` file)

**Auth**: Participant role in competition

**Response**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "team_id": "uuid",
  "competition_id": "uuid",
  "filename": "submission.zip",
  "format": "pytorch",
  "version": 1,
  "status": "scheduled",
  "submitted_at": "2026-05-07T18:00:00Z",
  "submitted_by": "uuid",
  "message": "Submission accepted. Version 1. Detected model format: pytorch."
}
```

#### Preview Submission Spec
```
GET /api/v1/competitions/{comp_id}/models/spec
```
**Returns**: Organizer-defined requirements for this competition.

#### List Competition Models
```
GET /api/v1/competitions/{comp_id}/models?page=1&limit=20
```

#### List Team Models (All Competitions)
```
GET /api/v1/teams/{team_id}/models?page=1&limit=20
```

#### Get Model Details
```
GET /api/v1/models/{model_id}
```

#### Get Team Submission History
```
GET /api/v1/teams/{team_id}/models/history?competition_id={comp_id}&page=1&limit=20
```
**Returns**: All versions with status breakdown.

#### Schedule Model for Evaluation
```
PUT /api/v1/models/{model_id}/schedule
```
**Auth**: Authenticated user (role enforcement pending)

#### Delete Model
```
DELETE /api/v1/models/{model_id}
```
**Auth**: Authenticated user (role enforcement pending)

---

## Service Layer

### Core Methods

#### `submit_model(team_id, competition_id, file, metadata, user_id)`

Executes the full submission pipeline:

1. **Validate zip extension** → Must be `.zip`
2. **Validate team eligibility** → Team exists, belongs to comp, user is member
3. **Validate phase** → Competition must be in `evaluation` phase
4. **Fetch organizer spec** → Load from `config.model_spec`
5. **Validate Docker submission** → Check all files, structure, requirements
6. **Generate hash** → SHA-256 for deduplication (app-level, no DB unique constraint)
7. **Check duplicates** → Reject if hash already exists (app-level check)
8. **Store zip** → Upload to MinIO / local fallback
9. **Persist** → Save Model and ModelMetadata records
10. **Auto-evaluate** → Read `Config.evaluation` for protocol, call `EvaluationOrchestrationService.scheduleEvaluation()`
     - Creates EvaluationJob + Tasks + queues to Celery
     - Model status: RECEIVED → SCHEDULED → QUEUED
     - Evaluation starts immediately via available workers

---

## Data Model

### Model Table

All ID columns are UUID (not integer), except `version`.

```sql
CREATE TABLE model (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id uuid NOT NULL REFERENCES team(id),
  competition_id uuid NOT NULL REFERENCES competition(id),
  submitted_by uuid NOT NULL REFERENCES "user"(id),
  filename varchar NOT NULL,
  storage_path varchar NOT NULL,
  model_hash varchar NOT NULL,
  format varchar(20) NOT NULL,  -- enum: tensorflow, pytorch, sklearn, keras, onnx
  framework_version varchar,
  size_mb float NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'received',  -- enum: received, validated, scheduled, queued, evaluating, completed
  version integer NOT NULL,
  submitted_at timestamp DEFAULT NOW(),
  scheduled_at timestamp,
  
  INDEX idx_model_submitted_by (submitted_by),
  INDEX idx_model_status (status),
  INDEX idx_model_hash (model_hash)
);
```

### ModelMetadata Table

```sql
CREATE TABLE model_metadata (
  id serial PRIMARY KEY,
  model_id uuid NOT NULL UNIQUE REFERENCES model(id) ON DELETE CASCADE,
  model_name varchar NOT NULL,
  description varchar,
  framework varchar NOT NULL,
  framework_version varchar,
  python_version varchar NOT NULL,
  dependencies jsonb,
  input_shape varchar,
  output_shape varchar,
  training_dataset varchar,
  performance_metrics jsonb,
  created_at timestamp DEFAULT NOW()
);
```

---

## Supported Formats

| Format | Extensions | Detection |
|---|---|---|
| **TensorFlow** | `.pb`, `.h5` | File extension in `model/` directory |
| **PyTorch** | `.pt`, `.pth` | File extension in `model/` directory |
| **Scikit-learn** | `.pkl`, `.pickle` | File extension in `model/` directory |
| **Keras** | `.h5` | File extension in `model/` directory |
| **ONNX** | `.onnx` | File extension in `model/` directory |

Format is **auto-detected** based on file extension in `model/` directory.

---

## Validation Rules

### Format Validation ✅
- File must be a valid `.zip` archive
- Must match one of the supported model formats

### Structure Validation ✅
- All `required_files` must exist in zip
- `model/` directory must contain a supported format file
- `data/` directory must exist (empty is fine)
- `Dockerfile` must have `FROM` and `CMD`/`ENTRYPOINT`
- `inference.py` must define the `inference_function` (default: `predict`)
- `requirements.txt` must list all `required_packages`

### Team Eligibility ✅
- Team must exist
- Team must belong to this competition
- Submitting user must be a team member

### Phase Validation ✅
- Competition must be in `evaluation` phase

### Deduplication ✅
- Model's SHA-256 hash must not already exist (app-level check)
- Prevents re-submission of unchanged models

### Size Validation ✅
- Zip file must be ≤ `max_size_mb` (default: 500 MB)

---

## Error Handling

### HTTP 400 Bad Request
- File is not a `.zip`
- Empty file uploaded
- Missing required files (Dockerfile, inference.py, requirements.txt)
- Missing model/ or data/ directory
- Unsupported model format
- Model file too large
- Missing required package in requirements.txt
- Inference function not defined in inference.py
- Duplicate model hash
- Wrong competition phase
- User not in team

### HTTP 401 Unauthorized
- Missing or invalid authorization token

### HTTP 403 Forbidden
- User lacks participant role in competition

### HTTP 404 Not Found
- Model not found
- Team not found
- Competition not found

---

## Testing

Run the comprehensive test suite:

```bash
pytest tests/test_model_submission_flow.py -v
```

**Test Classes**:
- `TestDockerSubmissionValidation` — 10 tests covering all validation rules
- `TestEligibilityAndPhase` — 6 tests for team and phase checks
- `TestDeduplication` — Hash-based duplicate detection
- `TestVersioning` — Auto-incrementing version per team

---

## Dependencies

- `model` table — Stores submission records (all FK columns are UUID)
- `model_metadata` table — Stores rich metadata
- `config.model_spec` — Organizer-defined requirements
- **Teams Service** — Validates team membership
- **Phase Service** — Validates competition phase
- **MinIO/Local Storage** — Stores zip files
- **Python `zipfile`** — Built-in, no extra dependency
- **Python `ast`** — Built-in, for parsing inference.py

---

## Future Enhancements

- [ ] Model signature validation (actually load and test locally)
- [ ] Dependency resolution check (`pip install` validation)
- [ ] Input/output shape validation against dataset specs
- [ ] Rate limiting per team
- [ ] Virus/malware scanning before storage
- [ ] S3 presigned URLs for downloads
- [ ] Webhook notifications on submission events
- [ ] Model diff/comparison between versions

---

## Implementation Status

**✅ COMPLETE**

All features implemented and tested:
- Docker-based submission format
- Comprehensive validation pipeline
- Team eligibility checks
- Phase gating
- Model deduplication (app-level)
- Version tracking
- Full CRUD API
- Error handling
- Test suite (25+ cases)
