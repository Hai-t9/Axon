# Module Breakdown — Validation

![Dashboard Diagram](../../static/diagrams/Validation.png)

## Overview

Handles the participant voting workflow for finalizing image labels. Each participant receives a queue of images to validate — 60% from their own team and 40% from other teams, making the split invisible to them. The queue size is defined by the host in the competition config. Once enough votes are collected, `finalizeLabel` computes the majority vote and persists the result via the Label module.

---

### Responsibility
Manages the full validation lifecycle: queue distribution, vote submission, and label finalization. The 60/40 split is enforced at the service level and hidden from participants. Cross-module dependency on Label for persisting finalized results.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `getValidationQueue` | `compId`, `participantId` | `{ images[ id, filepath ], total }` |
| `submitVote` | `imageId`, `validatorId`, `label` | `{ validation_id, label }` |
| `finalizeLabel` | `imageId` | `{ label_id, final_label, total_votes }` |
| `getPendingValidations` | `compId` | `{ images[ ], total }` |

### APIs

**Endpoints**
- `GET    /competitions/:compId/validations/queue` — Returns images awaiting validation for a participant — 60% own team / 40% other teams, limit from config
- `POST   /images/:imageId/validations` — Participant submits a validation vote for an image with their chosen label
- `POST   /images/:imageId/finalizeLabel` — Computes the final label from all votes via majority logic, then calls Label PUT to update
- `GET    /competitions/:compId/validations/pending` — Returns all images still pending final validation

**Controller**
- `handleGetValidationQueue(compId, participantId)`
- `handleSubmitVote(imageId)`
- `handleFinalizeLabel(imageId)`
- `handleGetPendingValidations(compId)`

**Service**
- `getValidationQueue(compId, participantId)`
  - → `findParticipantTeam(compId, participantId)`
  - → `findValidationLimit(compId)` — reads limit from `config`
  - → `findImagesFromOwnTeam(compId, teamId, participantId, count60)` — excludes already validated by this participant
  - → `findImagesFromOtherTeams(compId, teamId, participantId, count40)` — excludes already validated by this participant
  - → merge & return as single list
- `submitVote(imageId, validatorId, label)` → `insertVote(imageId, validatorId, label)`
- `finalizeLabel(imageId)`
  - → `findLabelByImageId(imageId)`
  - → `findVotesByLabelId(labelId)`
  - → `computeMajorityVote(votes)` — pure logic, no DB
  - → `LabelService.updateLabel(imageId, finalLabel)`
- `getPendingValidations(compId)` → `findPendingByComp(compId)`

**Repository**
- `findParticipantTeam(compId, participantId)`
- `findValidationLimit(compId)` — reads from `config`
- `findImagesFromOwnTeam(compId, teamId, participantId, count)` — excludes `image_id`s already in `label_validations` for this participant
- `findImagesFromOtherTeams(compId, teamId, participantId, count)` — same exclusion logic
- `insertVote(imageId, validatorId, label)`
- `findLabelByImageId(imageId)`
- `findVotesByLabelId(labelId)`
- `findPendingByComp(compId)`

### Dependencies
- `label`, `label_validations`, `image`, `team`, `config` tables
- **Label module** — `finalizeLabel` calls `LabelService.updateLabel` directly to persist the majority vote result
