# Module Breakdown — Label

![Dashboard Diagram](../../static/diagrams/Label.png)

## Overview

Manages image labels submitted by teams throughout the competition. Each image starts with an unvalidated label. The Validation module calls `updateLabel` internally when a label is finalized via majority vote.

---

### Responsibility
Handles full CRUD on image labels. The `validateLabel` endpoint is restricted to staff and host. The `updateLabel` endpoint is also called internally by the Validation module — not just by external clients.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `createLabel` | `imageId`, `label` | `{ id, image_id, label, validated: false }` |
| `getLabel` | `imageId` | `{ id, label, validated }` |
| `updateLabel` | `imageId`, `label` | `{ id, label, validated }` |
| `validateLabel` | `imageId` | `{ id, validated: true }` |

### APIs

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
- Called externally by **Validation module** (`finalizeLabel` → `LabelService.updateLabel`)
