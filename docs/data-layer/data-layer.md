---
sidebar_position: 1
---

# Data Layer

## Database Schema

### Core Entities

- **Teams**: Competition participants with metadata (team_id, organization, member_count, registration_date)
- **Images**: Agricultural field data with standardized attributes
  - `image_id`, `team_id`, `filename`, `device_info`, `metadata` (location, timestamp, environmental conditions)
  - `format` (JPEG, PNG), `resolution`, `storage_path`
- **Models**: Participant submissions with evaluation tracking
  - `model_id`, `team_id`, `submission_date`, `framework`, `version`
- **Evaluations**: Model performance records
  - `evaluation_id`, `model_id`, `dataset_fold`, `protocol_type` (LOTO, TOTO), `accuracy`, `timestamp`
- **Leaderboards**: Real-time rankings with historical snapshots
  - `leaderboard_id`, `evaluation_fold`, `team_rankings`, `updated_at`

### Relationships

```
Teams (1) ──→ (N) Images
Teams (1) ──→ (N) Models
Models (1) ──→ (N) Evaluations
Evaluations → Leaderboards
```

## Data Sources

### Primary Sources

1. **Mobile App (Field Collection)**
   - Direct image uploads from participants in agricultural environments
   - Captures device metadata (camera model, GPS, sensors) automatically
   - Environmental metadata: weather, soil conditions, growth stage

2. **Web Portal (Model Submissions)**
   - Team model files (PyTorch, TensorFlow)
   - Training logs and model checkpoints
   - Model metadata and hyperparameters

3. **External APIs**
   - Weather data: OpenWeatherMap or similar for enriching environmental context
   - GPS validation: coordinate verification for field locations

### Data Storage

- **Image Storage**: Cloud blob storage (AWS S3 / Azure Blob) with versioning
- **Database**: PostgreSQL for relational data with ACID compliance
- **Cache**: Redis for leaderboard ranking snapshots
- **Queue**: Message broker (RabbitMQ/Celery) for async evaluation tasks

## Data Pipelines

### 1. Ingestion Pipeline

**Flow**: Field Upload → Validation → Metadata Enrichment → Storage

```
Mobile App
    ↓
[Device Validation]
    ↓
[Metadata Auto-fill]  ← Extract: device_id, location, timestamp
    ↓
[Format Check]        ← Ensure JPEG/PNG, valid resolution
    ↓
[Cloud Storage]       ← S3/Azure with folder: /teams/{team_id}/images/
    ↓
[Database Insert]     ← Create Image record
```

**Frequency**: Real-time as users upload
**SLA**: \<2s for acknowledgment to user

### 2. Transformation Pipeline

**Flow**: Raw Data → Normalization → Standardization → Feature Extraction

```
Raw Images (varied sizes: 1080p, 4K, etc.)
    ↓
[Resize to 224x224]   ← Standard input for training
    ↓
[Color Normalization] ← ImageNet mean/std (if applicable)
    ↓
[Metadata JSON]       ← Extract: {device, location, timestamp, growth_stage}
    ↓
[Catalog Entry]       ← Indexed for rapid retrieval by fold/team
```

**Frequency**: Batch processing nightly or on-demand
**Storage**: Transformed images cached in `/processed/` directory

### 3. Validation Pipeline

**Flow**: Data Quality Checks → Schema Compliance → Business Rules

```
Incoming Data
    ↓
[Metadata Completeness] ← device_info, location, timestamp required
    ↓
[Image Quality]         ← Min resolution: 640x480, max file size: 50MB
    ↓
[Duplicate Detection]   ← Hash-based (MD5) to prevent duplicates
    ↓
[Team Quota Check]      ← Max 10,000 images per team
    ↓
[Pass/Fail Decision]    ↙            ↘
                   [Accept]      [Reject - Log Error]
                       ↓             ↓
                  [Mark Valid]  [Notify User]
```

**Rules**: See Validation Rules section below

### 4. Evaluation Pipeline (Async)

**Flow**: Model Submission → Preparation → Evaluation → Leaderboard Update

```
Model Upload (from team)
    ↓
[Model Validation]      ← Check format, framework compatibility
    ↓
[Environment Setup]     ← Spin up isolated container/VM
    ↓
[Data Preparation]
    ├─ LOTO Protocol: For each fold i, train on all but team i, test on team i
    ├─ TOTO Protocol: Train on single team's data, test on all other teams
    └─ Baseline: Standard train/test split
    ↓
[Model Inference]       ← Generate predictions on test set
    ↓
[Metrics Computation]   ← Accuracy, F1, confusion matrix
    ↓
[Leaderboard Update]    ← Rank teams, cache in Redis
    ↓
[Notification]          ← Alert team via email/UI
```

**Duration**: 5-30 mins per model (depends on dataset size)
**Queue**: Celery tasks dispatched to worker pool

## Validation Rules

### Metadata Validation

| Field | Type | Required | Constraints | Example |
|-------|------|----------|-------------|---------|
| `device_id` | String | ✓ | Predefined list | `iPhone_12_PRO` |
| `latitude` | Float | ✓ | -90 to 90 | `35.7638` |
| `longitude` | Float | ✓ | -180 to 180 | `139.7350` |
| `timestamp` | ISO 8601 | ✓ | Within competition period | `2026-05-03T14:30:00Z` |
| `growth_stage` | Enum | ✓ | {seedling, tillering, flowering, maturity} | `flowering` |
| `notes` | String | ✗ | Max 500 chars | `Morning shot, cloudy` |

### Image Validation

| Criterion | Rule | Action on Failure |
|-----------|------|-------------------|
| Format | JPEG or PNG only | Reject with error message |
| Resolution | Min 640×480, Max 4K | Resize if \>4K; reject if \<640×480 |
| File Size | \≤50 MB | Reject; suggest compression |
| Duplicate | MD5 hash not in database | Reject; notify user |
| Color Space | RGB or RGBA | Convert or reject if unsupported |

### Business Rules

- **Team Quota**: Max 10,000 images per team per competition
- **Submission Deadline**: Models accepted until competition end date
- **Model Size**: \≤500 MB to ensure inference feasibility
- **Evaluation Timeout**: 10 mins per model; abort if exceeded
- **Data Consistency**: No image can be removed after evaluation starts

### Error Handling

**Validation Failures** are logged with:
- Error code (e.g., `METADATA_INCOMPLETE`, `IMAGE_RESOLUTION_LOW`)
- User-friendly message
- Recommended action (retry, reformat, contact support)
- Timestamp and team_id for audit trail

```json
{
  "error_code": "METADATA_INCOMPLETE",
  "message": "Missing device_id. Please specify which camera took this photo.",
  "field": "device_id",
  "timestamp": "2026-05-03T14:35:22Z",
  "team_id": "team_42"
}
```
