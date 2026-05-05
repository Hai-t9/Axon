---
sidebar_position: 6
---

# Label

## Overview

The **Label Service** is a dedicated API service that manages image labels throughout the competition lifecycle. Each image starts with an unvalidated label, which then goes through the voting workflow in the Validation module. The Label Service handles all label CRUD operations and is called by both the Data Validation Service and the Validation module for label management and finalization.

---

### Responsibility

Handles full CRUD on image labels and label validation status. The `validateLabel` endpoint is restricted to staff and host roles. The `updateLabel` endpoint is called both externally (by Data Validation Service and teams) and internally (by Validation module when finalizing labels via majority vote).

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `createLabel` | `imageId`, `label` | `{ id, image_id, label, validated: false }` |
| `getLabel` | `imageId` | `{ id, label, validated }` |
| `updateLabel` | `imageId`, `label` | `{ id, label, validated }` |
| `validateLabel` | `imageId` | `{ id, validated: true }` |

### APIs

**Endpoints**
- `POST   /images/:imageId/labels` — Creates a new label for an image — starts as unvalidated
- `GET    /images/:imageId/labels` — Retrieves the current label and its validation status for an image
- `PUT    /images/:imageId/labels` — Updates an existing label — also called internally by Validation when finalizing
- `POST   /images/:imageId/labels/validate` — Marks a label as validated — staff and host only

**Controller**
- `handleCreateLabel(imageId)`
- `handleGetLabel(imageId)`
- `handleUpdateLabel(imageId)`
- `handleValidateLabel(imageId)`

**Service**
- `createLabel(imageId, label)` → `insertLabel(imageId, label)`
- `getLabel(imageId)` → `findLabelByImageId(imageId)`
- `updateLabel(imageId, label)` → `modifyLabel(imageId, label)`
- `validateLabel(imageId)` → `setLabelValidated(imageId)`

**Repository**
- `insertLabel(imageId, label)`
- `findLabelByImageId(imageId)`
- `modifyLabel(imageId, label)`
- `setLabelValidated(imageId)`

### Dependencies

- `label` table
- **Data Validation Service** — calls Label Service for label operations during validation workflow
- **Validation module** — calls `updateLabel` when finalizing labels via majority voting
- **Image module** — images have associated labels (1:1 relationship)
