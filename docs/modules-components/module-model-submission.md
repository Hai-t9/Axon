---
sidebar_position: 10
---

# Model Submission

## Overview

Handles participant model submissions during the evaluation phase. Manages model file uploads, validates model format and structure, stores models with versioning, tracks submission metadata, and schedules models for evaluation. Supports multiple model formats compatible with the evaluation framework.

---

### Responsibility

Receives model files from teams, performs format validation, stores models with version control, maintains submission history, and routes validated models to the Evaluation Orchestration Service for processing. Restricted to participants for submissions, hosts/staff for management.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `submitModel` | `teamId`, `modelFile`, `modelMetadata` | `{ id, team_id, filename, version, submitted_at, status }` |
| `validateModelFormat` | `file` | `{ valid: boolean, format, framework, requirements_met }` |
| `getTeamModelHistory` | `teamId`, `compId` | `{ models[ ], total, versions }` |
| `getModelBySubmission` | `modelId` | `{ id, team_id, filepath, version, submitted_at, status }` |
| `scheduleModelForEvaluation` | `modelId` | `{ model_id, scheduled: boolean, evaluation_status }` |

### APIs

**Endpoints**

- `POST   /competitions/:compId/models/submit` — Submit model for evaluation — participants only
- `GET    /competitions/:compId/models` — List all submitted models — host/staff/participants
- `GET    /teams/:teamId/models` — List team's submitted models
- `GET    /models/:modelId` — Get model details
- `PUT    /models/:modelId/schedule` — Schedule for evaluation — host/staff only
- `DELETE /models/:modelId` — Delete model submission — host/staff only
- `GET    /teams/:teamId/models/history` — Get model submission history

**Controller**

- `handleSubmitModel(teamId, file, metadata)`
- `handleGetModelsByCompetition(compId)`
- `handleGetTeamModels(teamId)`
- `handleGetModel(modelId)`
- `handleScheduleModelForEvaluation(modelId)`
- `handleDeleteModel(modelId)`
- `handleGetTeamModelHistory(teamId)`

**Service**

- `submitModel(teamId, file, metadata, userId)`
  - → `validateTeamEligibility(teamId)` — team met requirements
  - → `validateModelFormat(file)` — format, dependencies, structure
  - → `validateModelStructure(file)` — required files/format
  - → `generateModelHash(file)` — for dedup/tracking
  - → `storeModelFile(file)` → object storage
  - → `saveModelRecord(teamId, filepath, hash, metadata)`
  - → `scheduleForEvaluation(modelId)` — queue job
  - → return submission confirmation
- `validateModelFormat(file)` — check format compliance
- `validateModelStructure(file)` — check required files
- `getTeamModelHistory(teamId, compId)` → all versions submitted
- `getModelBySubmission(modelId)` → fetch model metadata
- `scheduleModelForEvaluation(modelId)`
  - → `validateModel(modelId)` — ensure valid model
  - → `createEvaluationJob(modelId)`
  - → `queueForEvaluation(modelId)`
  - → return scheduling confirmation

**Repository**

- `saveModelRecord(teamId, filepath, hash, metadata)`
- `findModelsByTeam(teamId, compId)`
- `findModelsByCompetition(compId)`
- `findModelById(modelId)`
- `updateModelStatus(modelId, status)`
- `deleteModel(modelId)`
- `countModelsByTeam(teamId)`

### Dependencies

- `model`, `model_submission_history` tables
- **Model Storage** (versioned object storage) — stores model files
- **Evaluation Orchestration Service** — receives models for evaluation
- **Teams Service** — validates team eligibility
- **Phase Service** — validates submission phase

### Data Model

**Model Submission Record**
```
{
  id: UUID,
  team_id: UUID,
  competition_id: UUID,
  filename: string,
  storage_path: string (S3/Blob URI),
  model_hash: string (SHA-256),
  format: enum('tensorflow' | 'pytorch' | 'sklearn' | 'keras' | 'onnx'),
  framework_version: string,
  size_mb: float,
  status: enum('received' | 'validated' | 'scheduled' | 'queued' | 'evaluating' | 'completed'),
  version: integer (auto-increment per team),
  submitted_at: timestamp,
  submitted_by: UUID,
  scheduled_at: timestamp (nullable)
}
```

**Model Metadata**
```
{
  model_id: UUID,
  model_name: string,
  description: string,
  framework: string,
  framework_version: string,
  python_version: string,
  dependencies: string[] (package list),
  input_shape: string,
  output_shape: string,
  training_dataset: string (description),
  performance_metrics: JSON (optional)
}
```

**Supported Formats**

- TensorFlow (SavedModel format)
- PyTorch (state_dict)
- Scikit-learn (pickle)
- Keras (.h5 or SavedModel)
- ONNX (for interoperability)

**Model Validation Rules**

- Format must be one of supported types
- Size limits: TBD by competition
- Required metadata: model_name, framework, python_version
- Dependencies must be resolvable
- Input/output shapes must match dataset specs
