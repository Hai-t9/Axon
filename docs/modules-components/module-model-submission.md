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
4. **Deduplicate**: Reject models with identical SHA-256 hashes
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
- `team_id` (int) — Team submitting
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
  "team_id": 5,
  "competition_id": 1,
  "filename": "submission.zip",
  "format": "pytorch",
  "version": 1,
  "status": "scheduled",
  "submitted_at": "2026-05-07T18:00:00Z",
  "submitted_by": 123,
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
GET /api/v1/teams/{team_id}/models/history?competition_id={comp_id}
```
**Returns**: All versions with status breakdown.

#### Schedule Model for Evaluation
```
PUT /api/v1/models/{model_id}/schedule
```
**Auth**: Host or Staff role

#### Delete Model
```
DELETE /api/v1/models/{model_id}
```
**Auth**: Host or Staff role

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
6. **Generate hash** → SHA-256 for deduplication
7. **Check duplicates** → Reject if hash already exists
8. **Store zip** → Upload to MinIO / local fallback
9. **Persist** → Save Model and ModelMetadata records
10. **Auto-schedule** → Set status to SCHEDULED

#### `validate_docker_submission(zip_bytes, spec)`

Validates the zip against organizer's requirements:

- **File checks**: `Dockerfile`, `inference.py`, `requirements.txt` exist
- **Directory checks**: `model/` contains a supported format, `data/` exists
- **AST parsing**: Confirms `inference_function` is defined in `inference.py`
- **Requirements parsing**: Verifies all `required_packages` are listed
- **Dockerfile parsing**: Confirms `FROM` and `CMD`/`ENTRYPOINT` instructions
- **Size validation**: Zip must be ≤ `max_size_mb`

Returns detected model format: `pytorch`, `tensorflow`, `sklearn`, `keras`, or `onnx`.

#### `_validate_team_eligibility(team_id, competition_id, user_id)`

Ensures:
- Team with `team_id` exists
- Team belongs to `competition_id`
- User is a member of the team

#### `_validate_submission_phase(competition_id)`

Ensures competition is in `evaluation` phase. Rejects submissions during other phases.

---

## Repository Layer

### Methods

| Method | Purpose |
|---|---|
| `save_model_record(...)` | Persist Model to DB |
| `save_model_metadata(...)` | Persist ModelMetadata to DB |
| `find_by_id(model_id)` | Fetch single model |
| `find_by_hash(hash)` | Check for duplicates |
| `find_by_team(team_id, comp_id)` | Get team's models in comp |
| `find_by_competition(comp_id)` | Get all models in comp |
| `find_latest_by_team(team_id, comp_id)` | Get latest version |
| `find_all_by_team(team_id)` | Get all models across comps |
| `update_status(model_id, status)` | Change model state |
| `delete_model(model_id)` | Remove model and metadata |
| `find_competition_config(comp_id)` | Fetch organizer spec |
| `find_team(team_id)` | Verify team exists |
| `find_phase(comp_id)` | Check current phase |

---

## Data Model

### Model Table

```sql
CREATE TABLE model (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id integer NOT NULL REFERENCES team(id),
  competition_id integer NOT NULL REFERENCES competition(id),
  submitted_by integer NOT NULL REFERENCES "user"(id),
  filename varchar NOT NULL,
  storage_path varchar NOT NULL,
  model_hash varchar NOT NULL UNIQUE,
  format varchar(20) NOT NULL,  -- enum: tensorflow, pytorch, sklearn, keras, onnx
  framework_version varchar,
  size_mb float NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'received',  -- enum: received, validated, scheduled, queued, evaluating, completed
  version integer NOT NULL,
  submitted_at timestamp DEFAULT NOW(),
  scheduled_at timestamp,
  
  CONSTRAINT uq_model_team_version UNIQUE (team_id, competition_id, version),
  INDEX idx_model_team_id (team_id),
  INDEX idx_model_competition_id (competition_id),
  INDEX idx_model_status (status),
  INDEX idx_model_hash (model_hash),
  INDEX idx_model_team_competition_version (team_id, competition_id, version DESC)
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
  dependencies jsonb,  -- ["numpy>=1.20", "torch>=1.9"]
  input_shape varchar,
  output_shape varchar,
  training_dataset varchar,
  performance_metrics jsonb,
  created_at timestamp DEFAULT NOW()
);
```

### Config Table (Updated)

```sql
ALTER TABLE config ADD COLUMN model_spec jsonb DEFAULT NULL;
```

Organizers set `model_spec` to define submission requirements.

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
- Model's SHA-256 hash must not already exist
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
- Host/Staff-only operation (schedule, delete) attempted by non-staff

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

**Test Coverage**: 25+ test cases covering happy path, edge cases, and error conditions.

---

## Dependencies

- `model` table — Stores submission records
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
- Model deduplication
- Version tracking
- Full CRUD API
- Error handling
- Test suite (25+ cases)
