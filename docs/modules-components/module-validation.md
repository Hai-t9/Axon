---
sidebar_position: 9
---

# Validation

![Dashboard Diagram](../../static/diagrams/Validation.png)

## Overview

Handles the participant voting workflow for finalizing image labels. Each participant receives one image at a time to validate — approximately 60% from their own team and 40% from other teams, making the split invisible to them. The split is maintained dynamically across the participant's session. Once enough votes are collected, `finalizeLabel` computes the majority vote and persists the result via the Label module.

---

### Responsibility
Manages the full validation lifecycle: one-at-a-time image distribution, vote submission, and label finalization. The 60/40 split is enforced dynamically at the service level by tracking the participant's validation history. Images that have reached the maximum vote threshold are excluded from the queue. Cross-module dependency on Label for persisting finalized results.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `getNextValidationImage` | `compId`, `participantId` | `{ id, filepath }` |
| `submitVote` | `imageId`, `validatorId`, `label` | `{ validation_id, label }` |
| `finalizeLabel` | `imageId` | `{ label_id, final_label, total_votes }` |
| `getPendingValidations` | `compId` | `{ images[ ], total }` |

### APIs

**Endpoints**
- `GET    /competitions/:compId/validations/next` — Returns the next single image for a participant to validate — respects 60/40 split and threshold cap
- `POST   /images/:imageId/validations` — Participant submits a validation vote for an image with their chosen label
- `POST   /images/:imageId/finalizeLabel` — Computes the final label from all votes via majority logic, then calls Label PUT to update
- `GET    /competitions/:compId/validations/pending` — Returns all images still pending final validation

**Controller**
- `handleGetNextValidationImage(compId, participantId)`
- `handleSubmitVote(imageId)`
- `handleFinalizeLabel(imageId)`
- `handleGetPendingValidations(compId)`

**Service**
- `getNextValidationImage(compId, participantId)`
  - → `findParticipantTeam(compId, participantId)`
  - → `findValidationThreshold(compId)` — reads max votes per image from `config`
  - → `countParticipantValidations(participantId)` — gets `ownCount` & `otherCount` from `label_validations`
  - → decide pool based on 60/40 ratio (pure logic, no DB)
  - → `findNextImageFromOwnTeam(compId, teamId, participantId, threshold)` or `findNextImageFromOtherTeams(compId, teamId, participantId, threshold)`
  - → return single image `{ id, filepath }`
- `submitVote(imageId, validatorId, label)` → `insertVote(imageId, validatorId, label)`
- `finalizeLabel(imageId)`
  - → `findLabelByImageId(imageId)`
  - → `findVotesByLabelId(labelId)`
  - → `computeMajorityVote(votes)` — pure logic, no DB
  - → `LabelService.updateLabel(imageId, finalLabel)`
- `getPendingValidations(compId)` → `findPendingByComp(compId)`

**Repository**
- `findParticipantTeam(compId, participantId)`
- `findValidationThreshold(compId)` — reads from `config`
- `countParticipantValidations(participantId)` — counts own team vs other teams validations from `label_validations`
- `findNextImageFromOwnTeam(compId, teamId, participantId, threshold)` — excludes already voted by participant + images at threshold cap
- `findNextImageFromOtherTeams(compId, teamId, participantId, threshold)` — same exclusion logic
- `insertVote(imageId, validatorId, label)`
- `findLabelByImageId(imageId)`
- `findVotesByLabelId(labelId)`
- `findPendingByComp(compId)`

### Dependencies
- `label`, `label_validations`, `image`, `team`, `config` tables
- **Label module** — `finalizeLabel` calls `LabelService.updateLabel` directly to persist the majority vote result