---
sidebar_position: 6
---

# Label

## Overview

The **Label Service** is a dedicated API service that manages image labels throughout the competition lifecycle. Each image starts with an unvalidated label, which then goes through the voting workflow in the Validation module. The Label Service handles all label CRUD operations and is called by both the Data Validation Service and the Validation module for label management and finalization.

When updating labels, the service automatically manages file relocations in both S3 and local storage, moving image files from the old label folder to the new label folder structure while keeping database records in sync.

---

## Responsibility

Handles full CRUD on image labels and label validation status. The `validateLabel` endpoint is restricted to staff and host roles. The `updateLabel` endpoint is called both externally (by Data Validation Service and teams) and internally (by Validation module when finalizing labels via majority vote).

When a label is updated, the service also:
- Moves the image file from old label folder to new label folder in S3 (always)
- Moves the image file locally if it exists (best effort)
- Updates Image.filepath to the new location
- Syncs Image.label field to keep gallery display current

When a label is validated:
- Sets Label.validated = True
- Sets Image.status = "verified"

---

## Inputs / Outputs

| Function | Input | Output |
|---------|--------|--------|
| `createLabel` | `imageId`, `label` | `{ id, image_id, label, validated: false }` |
| `getLabel` | `imageId` | `{ id, image_id, label, validated }` |
| `updateLabel` | `imageId`, `label` | `{ id, image_id, label, validated }` (+ file moved) |
| `validateLabel` | `imageId` | `{ id, validated: true }` (+ status set to verified) |
| `getCompetitionId` | `imageId` | `UUID` (competition_id) |

---

## APIs

### Endpoints

- `POST /images/:imageId/labels`
  - Creates a new label for an image — starts as unvalidated
  - Authenticated users only
  - Payload: `{ label: string }`
  - Returns `LabelResponse`

- `GET /images/:imageId/labels`
  - Retrieves the current label and its validation status for an image
  - Authenticated users only
  - Returns `LabelResponse`

- `PUT /images/:imageId/labels`
  - Updates an existing label — also called internally by Validation when finalizing
  - Authenticated users only
  - Triggers file relocation in storage
  - Payload: `{ label: string }`
  - Returns `LabelResponse`

- `POST /images/:imageId/labels/validate`
  - Marks a label as validated and sets image status to verified
  - Host and staff only (role-gated)
  - Returns `LabelValidationResponse`

---

## Controller

- `createLabel(imageId, payload, authorization, auth_service, label_service)`
  - Validates authorization (all authenticated users)
  - Calls `label_service.create_label(imageId, payload.label)`
  - Returns `LabelResponse`

- `getLabel(imageId, authorization, auth_service, label_service)`
  - Validates authorization (all authenticated users)
  - Calls `label_service.get_label(imageId)`
  - Returns `LabelResponse`

- `updateLabel(imageId, payload, authorization, auth_service, label_service)`
  - Validates authorization (all authenticated users)
  - Calls `label_service.update_label(imageId, payload.label)`
  - Handles file relocation automatically
  - Returns `LabelResponse`

- `validateLabel(imageId, authorization, auth_service, label_service)`
  - Validates authorization (host/staff only)
  - Requires role check against competition_id
  - Calls `label_service.validate_label(imageId)`
  - Returns `LabelValidationResponse`

---

## Service

### getCompetitionId(imageId)
- Fetch competition_id for image via `get_competition_id_for_image(imageId)`
- Raise `NotFoundError` if image not found
- Return `UUID`

### createLabel(imageId, label)
- Validate image exists via `get_image_by_id(imageId)`
- Validate no label already exists via `find_by_image_id(imageId)`
- Call `insert_label(imageId, label)`
- Return `LabelResponse`

### getLabel(imageId)
- Fetch label via `find_by_image_id(imageId)`
- Raise `NotFoundError` if not found
- Return `LabelResponse`

### updateLabel(imageId, newLabel)
1. Validate image exists via `get_image_by_id(imageId)`
2. Fetch existing label via `find_by_image_id(imageId)`
3. If label == newLabel, return existing label (no-op)
4. Fetch image with team/competition info
5. Compute old and new file paths:
   - Old: `image_local_path(compId, teamId, compName, teamName, oldLabel, filename)`
   - New: `image_local_path(compId, teamId, compName, teamName, newLabel, filename)`
   - Old S3: `image_key(compId, teamId, compName, teamName, oldLabel, filename)`
   - New S3: `image_key(compId, teamId, compName, teamName, newLabel, filename)`
6. Move in S3 (always):
   - `storage_service.copy_file(oldS3, newS3)`
   - `storage_service.delete_file(oldS3)`
7. Move locally (if exists):
   - Create parent directory if needed
   - `shutil.move(oldLocal, newLocal)`
8. Update database:
   - `update_image_filepath(imageId, newLocal)` - sync filepath
   - `modify_label(imageId, newLabel)` - update Label.label
   - `update_image_label(imageId, newLabel)` - sync Image.label
9. Return updated label

### validateLabel(imageId)
1. Call `set_label_validated(imageId)` to set Label.validated = True
2. Call `set_image_status(imageId, "verified")` to update Image.status
3. Return `LabelValidationResponse`

---

## Repository

### Core Methods
- `get_image_by_id(imageId)` → `Image | None`
- `get_competition_id_for_image(imageId)` → `UUID | None` (via team join)
- `find_by_image_id(imageId)` → `Label | None`
- `get_image_with_team(imageId)` → `Image | None` (with team loaded)

### Insert/Update Methods
- `insert_label(imageId, label)` → `Label` (creates new, validated=False)
- `modify_label(imageId, label)` → `Label | None` (updates Label.label only)
- `set_label_validated(imageId)` → `Label | None` (sets validated=True)

### File & Status Sync Methods
- `update_image_filepath(imageId, newFilepath)` → `None` (updates Image.filepath)
- `update_image_label(imageId, label)` → `None` (updates Image.label for gallery sync)
- `set_image_status(imageId, status)` → `None` (updates Image.status)

---

## Request/Response Schemas

### LabelCreate
```json
{
  "label": "cat"
}
```

### LabelUpdate
```json
{
  "label": "dog"
}
```

### LabelResponse
```json
{
  "id": 1,
  "image_id": "550e8400-e29b-41d4-a716-446655440000",
  "label": "cat",
  "validated": false
}
```

### LabelValidationResponse
```json
{
  "id": 1,
  "validated": true
}
```

---

## File Relocation Logic

When a label is updated, the image file is relocated to match the new label's folder structure.

**Paths:**
- Local: `/uploads/{compId}/{teamId}/{compName}/{teamName}/{label}/{filename}`
- S3: `{compId}/{teamId}/{compName}/{teamName}/{label}/{filename}`

**Process:**
1. Compute old and new paths based on image metadata
2. Always copy and delete in S3 (atomic operation)
3. Locally, move file only if it exists (best effort - doesn't fail if missing)
4. Update Image.filepath in database to point to new location
5. Update Image.label to keep gallery display in sync
6. Update Label.label with new value

**Why?** Images are organized by label in storage, so changing a label requires moving the file to maintain the folder structure. The database tracks both Label.label (voting metadata) and Image.label (gallery display) to ensure consistency.

---

## Dependencies

- `image` table - for filepath, label, status, and team_id
- `label` table - for validation status and label value
- `team` table - for comp_id, team_id lookups
- **Storage Service (S3)** - for file copy/delete operations
- **File System** - for local file moves
- **Data Validation Service** — calls Label Service for initial label creation
- **Validation module** — calls `updateLabel` when finalizing labels via majority voting

---

## Key Behaviors

1. **Create Guard**: Cannot create label if one already exists for image
2. **No-op on Same Value**: If new label == old label, returns existing without file movement
3. **Atomic File Movement**: S3 copy+delete happens regardless of local file presence
4. **Best Effort Local Move**: Doesn't fail if local file doesn't exist (synced from elsewhere)
5. **Dual Sync**: Both Label.label and Image.label updated to keep voting and gallery in sync
6. **Status Update on Validate**: Validates label and sets image status to "verified" together
7. **Competition Gating on Validate**: Role check requires host or staff in the image's competition

---

## Final System Definition

> A label management service that handles CRUD operations on image labels, with automatic file relocation across S3 and local storage when labels change, database synchronization to keep voting and gallery views consistent, and validation workflows tied to image status tracking.
