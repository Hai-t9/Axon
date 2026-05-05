---
sidebar_position: 9
---

# Validation

![Dashboard Diagram](../../static/diagrams/Validation.png)

## Overview

Handles the participant voting workflow for finalizing image labels. Each participant receives a batch of 10 images at a time to validate — 6 from their own team (60%) and 4 from other teams (40%), making the split invisible to them. The split is maintained dynamically across the participant's session by tracking their full validation history. Once an image reaches the vote threshold, it is automatically finalized via majority vote and marked as validated — no manual trigger needed.

---

### Responsibility
Manages the full validation lifecycle: batch image distribution, vote submission, and automatic label finalization.

**Batch logic:**
- Each batch is exactly 10 images: 6 from own team, 4 from other teams
- The 60/40 ratio is computed from the participant's full history (`ownCount` & `otherCount`) and applied per batch
- Both pool queries (`findBatchFromOwnTeam` and `findBatchFromOtherTeams`) apply all 3 exclusion filters in a single DB query each:
  1. Images already voted on by this participant
  2. Images whose vote count has reached or exceeded the threshold
  3. Images already finalized (`label.validated = true`)

**Finalization logic:**
- Triggered automatically inside `submitVote` — no separate endpoint
- After every vote insert, the vote count is checked against the threshold
- If reached: majority vote is computed (pure logic) and Label module is called to update and mark the label as validated
- Minor threshold exceed of 1-2 votes is acceptable due to concurrent batching and does not affect the majority result

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `getValidationBatch` | `compId`, `participantId` | `{ images[ id, filepath ] }` |
| `submitVote` | `imageId`, `validatorId`, `label` | `{ validation_id, label }` |
| `getPendingValidations` | `compId` | `{ images[ ], total }` |

### APIs

**Endpoints**
- `GET    /competitions/:compId/validations/batch` — Returns a batch of 10 images (6 own team + 4 others) — excludes already voted, threshold-reached, and finalized images
- `POST   /images/:imageId/validations` — Participant submits a validation vote — automatically finalizes label if threshold is reached
- `GET    /competitions/:compId/validations/pending` — Returns all images still pending final validation

**Controller**
- `handleGetValidationBatch(compId, participantId)`
- `handleSubmitVote(imageId)`
- `handleGetPendingValidations(compId)`

**Service**
- `getValidationBatch(compId, participantId)`
  - → `findParticipantTeam(compId, participantId)`
  - → `findValidationThreshold(compId)` — reads max votes per image from `config`
  - → `countParticipantValidations(participantId)` — gets `ownCount` & `otherCount` from `label_validations`
  - → compute `count60 = 6`, `count40 = 4` (pure logic, no DB)
  - → `findBatchFromOwnTeam(compId, teamId, participantId, threshold, count60)`
  - → `findBatchFromOtherTeams(compId, teamId, participantId, threshold, count40)`
  - → merge & return batch of 10
- `submitVote(imageId, validatorId, label)`
  - → `insertVote(imageId, validatorId, label)`
  - → `countVotesForImage(imageId)`
  - → if votes >= threshold:
    - → `findLabelByImageId(imageId)`
    - → `findVotesByLabelId(labelId)`
    - → `computeMajorityVote(votes)` — pure logic, no DB
    - → `LabelService.updateLabel(imageId, finalLabel)`
    - → `LabelService.setLabelValidated(imageId)`
- `getPendingValidations(compId)` → `findPendingByComp(compId)`

**Repository**
- `findParticipantTeam(compId, participantId)`
- `findValidationThreshold(compId)` — reads from `config`
- `countParticipantValidations(participantId)` — returns `{ ownCount, otherCount }` from `label_validations` joined with `image` and `team`
- `findBatchFromOwnTeam(compId, teamId, participantId, threshold, count)` — single query excluding: already voted by participant + vote count >= threshold + `label.validated = true`
- `findBatchFromOtherTeams(compId, teamId, participantId, threshold, count)` — same single query exclusion logic
- `insertVote(imageId, validatorId, label)`
- `countVotesForImage(imageId)`
- `findLabelByImageId(imageId)`
- `findVotesByLabelId(labelId)`
- `findPendingByComp(compId)`

### Dependencies
- `label`, `label_validations`, `image`, `team`, `config` tables
- **Label module** — `submitVote` automatically calls `LabelService.updateLabel` and `LabelService.setLabelValidated` when threshold is reached to persist and finalize the majority vote result