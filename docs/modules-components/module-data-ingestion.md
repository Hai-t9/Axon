---
sidebar_position: 4
---

# Data Ingestion

## Overview

Manages field image data collection and initial ingestion into the system. Handles image uploads from mobile applications, validates metadata completeness and format, stores images in distributed file storage, tracks image versioning, and ensures standardized formats and resolution. Queues validated images for team validation workflows.

---

### Responsibility

Receives image uploads from mobile apps, performs format and metadata validation, stores images in object storage, maintains image records with metadata, and routes images to the validation workflow. Enforces data quality rules at ingestion time.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `ingestImage` | `teamId`, `file`, `metadata` | `{ id, team_id, filepath, storage_path, status, created_at }` |
| `validateImageMetadata` | `metadata` | `{ valid: boolean, errors[ ] }` |
| `validateImageFormat` | `file` | `{ valid: boolean, format, size_mb }` |
| `getImageIngestionStats` | `compId` | `{ total_images, accepted, rejected, pending_validation }` |
| `retryFailedIngestion` | `imageId` | `{ id, status, retry_count }` |

### APIs

**Endpoints**

- `POST   /teams/:teamId/images/ingest` — Upload and ingest image — authenticated team members only
- `POST   /teams/:teamId/images/batch-ingest` — Batch upload multiple images — authenticated team members only
- `GET    /teams/:teamId/ingestion/stats` — Get ingestion statistics for team
- `GET    /competitions/:compId/ingestion/stats` — Get ingestion statistics for competition — host/staff only
- `POST   /images/:imageId/retry-ingestion` — Retry failed ingestion — host/staff only

**Controller**

- `handleIngestImage(teamId, file, metadata)`
- `handleBatchIngestImages(teamId, files, metadata[])`
- `handleGetTeamIngestionStats(teamId)`
- `handleGetCompetitionIngestionStats(compId)`
- `handleRetryFailedIngestion(imageId)`

**Service**

- `ingestImage(teamId, file, metadata, userId)`
  - → `validateImageFormat(file)` — JPEG/PNG, size limits
  - → `validateImageMetadata(metadata)` — device info, GPS, timestamp
  - → `generateImageHash(file)` — for deduplication
  - → `storeImageFile(file)` → S3/Blob storage
  - → `saveImageRecord(teamId, filepath, hash, metadata)`
  - → `queueForValidation(imageId)`
  - → return ingestion result
- `validateImageMetadata(metadata)` — pure validation logic
- `validateImageFormat(file)` — pure validation logic
- `getImageIngestionStats(compId)` → aggregated stats
- `retryFailedIngestion(imageId)` → re-run ingestion pipeline

**Repository**

- `saveImageRecord(teamId, filepath, hash, metadata)`
- `findImagesByTeam(teamId)`
- `findImagesByCompetition(compId)`
- `updateImageStatus(imageId, status)`
- `countImagesByStatus(compId)`
- `findFailedImages(compId)`

### Dependencies

- `image`, `image_metadata` tables
- **Image Storage** (S3/Blob) — stores actual image files
- **Data Validation Service** — receives validated images for team review
- **Teams Service** — validates team ownership

### Data Model

**Image Ingestion Record**
```
{
  id: UUID,
  team_id: UUID,
  competition_id: UUID,
  filepath: string (relative to storage),
  storage_path: string (S3/Blob URI),
  image_hash: string (SHA-256 for dedup),
  size_mb: float,
  format: enum('JPEG' | 'PNG'),
  status: enum('pending' | 'validated' | 'failed'),
  upload_timestamp: timestamp,
  uploaded_by: UUID
}
```

**Image Metadata**
```
{
  image_id: UUID,
  device_name: string,
  device_model: string,
  camera_info: string,
  gps_latitude: float (nullable),
  gps_longitude: float (nullable),
  gps_altitude: float (nullable),
  timestamp: timestamp,
  timezone: string,
  weather_conditions: string (nullable),
  extracted_at: timestamp
}
```

**Validation Rules**

- Device information completeness (no metadata loss)
- Image format standardization (JPEG/PNG only)
- Resolution requirements (TBD)
- Timestamp consistency (not future-dated)
- File size limits (TBD by competition)
- Metadata must include: device name, device model, timestamp, location (if applicable)
