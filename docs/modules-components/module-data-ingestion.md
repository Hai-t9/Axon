---
sidebar_position: 4
---

# Data Ingestion

## Overview

Data ingestion is handled through the **Image Module** (see [Image Module Documentation](./module-image.md)). There is no separate Data Ingestion service — image upload, format validation, metadata extraction, and storage are all managed by the Image module's single upload endpoint.

---

### Responsibility

Image upload and validation are performed by the Image Service. The Image module handles receiving files, validating format/size, deduplication via hashing, metadata extraction (EXIF), and storing to either MinIO/S3 or local fallback storage.

### How Ingestion Works

```
Mobile App / Web Portal
    ↓
POST /api/v1/teams/{team_id}/images  (multipart: file + optional label)
    ↓
Image Service
    ├→ validateImageFormat(file) — JPEG/PNG only
    ├→ validateImageSize(file) — max 50MB
    ├→ generateImageHash(file) — SHA-256 for dedup
    ├→ checkDuplicateImage(hash)
    ├→ storeImageFile(file) → MinIO / local fallback
    ├→ saveImageRecord(userId, teamId, filepath, hash)
    ├→ extractMetadata(file) — EXIF data
    └→ storeImageMetadata(imageId, metadata)
```

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `uploadImage` | `userId`, `teamId`, `file`, `label?` | `{ id, team_id, filepath, image_hash, status, metadata }` |

### APIs

**Endpoint**

- `POST   /api/v1/teams/{team_id}/images` — Upload and ingest image — authenticated team members only

**Controller** (image/controller.py)

- `handleUploadImage(teamId, file, label)`

**Service** (image/service.py)

- `uploadImage(userId, teamId, file, label)`
  - → `validateImageFormat(file)` — JPEG/PNG, size limits
  - → `validateImageSize(file)` — max 50MB
  - → `generateImageHash(file)` — for deduplication
  - → `checkDuplicateImage(hash)` — app-level check
  - → `storeImageFile(file)` → MinIO/local storage
  - → `saveImageRecord(userId, teamId, filepath, hash, label)`
  - → `extractMetadata(file)` → EXIF parsing
  - → `storeImageMetadata(imageId, metadata)`
  - → return ingestion result

**Repository**

- `create(data)`
- `findById(imageId)`
- `findByHash(hash)`
- `findByTeam(teamId)`
- `findByCompetition(compId)`
- `findByStatus(status)`
- `updateStatus(imageId, status)`
- `delete(imageId)`
- `countByTeam(teamId)`
- `countByStatus(status)`

### Dependencies

- `image`, `image_metadata` tables
- **Image Storage** (MinIO S3 or local filesystem fallback) — stores actual image files
- **Teams Service** — validates team ownership

### Data Model

**Image Record**
```
{
  id: integer (PK),
  team_id: UUID,
  author_id: UUID,
  filepath: string (relative unique path),
  image_hash: string (SHA-256 for dedup),
  status: enum('onhold' | 'verified'),
  original_filename: string,
  old_extension: string,
  old_size_mb: float,
  old_width: float,
  old_height: float,
  device: string,
  time: timestamp
}
```

**Image Metadata**
Stored in `image_metadata` table 1:1 with image.
Contains EXIF fields: GPSInfo, Make, Model, Software, Orientation, DateTime, resolutions, processing info, scientific/english names, etc.

### Validation Rules (enforced at upload)

- Image format: JPEG/PNG only
- File size: max 50MB
- Duplicate detection via SHA-256 hash (app-level)
- Metadata extracted automatically from EXIF
