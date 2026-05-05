---
sidebar_position: 8
---

# Data Validation

## Overview

Coordinates the data validation workflow where teams review and correct image labels collected during data ingestion. Manages validation queues, displays images with metadata, handles label corrections, tracks validation progress, and ensures validation deadlines are respected. Acts as the workflow orchestrator between image collection and model evaluation phases.

---

### Responsibility

Orchestrates the validation lifecycle: queue management, image display coordination, label review workflows, deadline enforcement, and validation completion tracking. Delegates label persistence to the Label Service. Provides interfaces for teams to review and correct image labels with audit trail.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `getValidationQueue` | `compId`, `teamId`, `limit` | `{ images[ ], total, queue_size }` |
| `submitLabelCorrection` | `imageId`, `teamId`, `correctedLabel` | `{ id, image_id, label, corrected_at }` |
| `getValidationProgress` | `compId` | `{ teams[ { team, images_validated, images_pending } ], overall_progress }` |
| `completeTeamValidation` | `teamId` | `{ team_id, validation_completed_at }` |
| `enforceValidationDeadline` | `compId` | `{ completed: boolean, locked_images }` |

### APIs

**Endpoints**

- `GET    /competitions/:compId/data-validation/queue` — Get validation queue for team
- `POST   /images/:imageId/data-validation/correct` — Submit label correction
- `GET    /competitions/:compId/data-validation/progress` — Get validation progress — host/staff only
- `GET    /teams/:teamId/data-validation/stats` — Get team validation statistics
- `POST   /competitions/:compId/data-validation/complete` — Mark validation complete and lock labels — host/staff only
- `GET    /competitions/:compId/data-validation/deadline` — Get validation deadline info

**Controller**

- `handleGetValidationQueue(compId, teamId)`
- `handleSubmitLabelCorrection(imageId, teamId, label)`
- `handleGetValidationProgress(compId)`
- `handleGetTeamValidationStats(teamId)`
- `handleCompleteTeamValidation(teamId)`
- `handleEnforceValidationDeadline(compId)`

**Service**

- `getValidationQueue(compId, teamId, limit)`
  - → `findImagesForTeam(teamId, limit)`
  - → `enrichWithLabelInfo(images)`
  - → return images with current labels
- `submitLabelCorrection(imageId, teamId, correctedLabel, userId)`
  - → `validateTeamOwnership(imageId, teamId)`
  - → `LabelService.updateLabel(imageId, correctedLabel)` — delegate to Label Service
  - → `logValidationActivity(imageId, userId, correctedLabel)`
  - → return confirmation
- `getValidationProgress(compId)`
  - → `findTeamsByCompetition(compId)`
  - → `countValidatedImages(compId)` per team
  - → `countPendingImages(compId)` per team
  - → compute overall progress percentage
  - → return aggregated stats
- `completeTeamValidation(teamId)`
  - → `lockTeamLabels(teamId)` — prevent further changes
  - → `createValidationCompletion(teamId)`
  - → return completion record
- `enforceValidationDeadline(compId)`
  - → `getPhaseDeadline(compId)` — from Phase Service
  - → `lockAllPendingLabels(compId)` if deadline passed
  - → `notifyTeamsOfDeadline(compId)`
  - → return enforcement result

**Repository**

- `findImagesForTeam(teamId, limit)` — images not yet validated by team
- `countValidatedImages(teamId)`
- `countPendingImages(teamId)`
- `lockTeamLabels(teamId)`
- `logValidationActivity(imageId, userId, action, details)`
- `findValidationDeadline(compId)`
- `createValidationCompletion(teamId, timestamp)`

### Dependencies

- `image`, `label`, `validation_activity` tables
- **Label Service** — calls `updateLabel` to persist label corrections
- **Phase Service** — reads validation deadline from phase info
- **Image module** — retrieves images for validation
- **Teams Service** — validates team membership

### Data Model

**Validation Queue Item**
```
{
  image_id: UUID,
  team_id: UUID,
  filepath: string,
  current_label: string,
  label_status: enum('unvalidated' | 'corrected' | 'locked'),
  collected_by_team: UUID,
  device_info: string,
  timestamp: timestamp
}
```

**Validation Activity Log**
```
{
  id: UUID,
  image_id: UUID,
  team_id: UUID,
  activity_type: enum('view' | 'correct' | 'confirm' | 'lock'),
  performed_by: UUID,
  old_label: string (nullable),
  new_label: string (nullable),
  performed_at: timestamp
}
```

**Validation Progress**
```
{
  competition_id: UUID,
  team_id: UUID,
  total_images: integer,
  validated_images: integer,
  pending_images: integer,
  locked_images: integer,
  progress_percentage: float,
  last_updated: timestamp
}
```

### Workflow

```
1. Team receives validation queue
   └─ Mixed dataset: 60% own team images, 40% other teams (hidden)
2. Team reviews each image with current label
3. Team confirms label OR submits correction
   └─ Calls Label Service to update
4. Validation activity logged for audit
5. Deadline enforced by Phase Service
6. Validated labels locked before evaluation
```
