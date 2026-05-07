---
sidebar_position: 9
---

# Validation

![Dashboard Diagram](../../static/diagrams/Validation.png)

## Overview

Handles the participant voting workflow for finalizing image labels. Each participant receives one image at a time to validate — the split is maintained dynamically at approximately 60% from their own team and 40% from other teams, making the split completely invisible to them. The pool is always fresh at the moment of each request. Once an image accumulates enough votes to reach the threshold, it is automatically finalized via majority vote and marked as validated — no manual trigger needed.

---

### Responsibility
Manages the full validation lifecycle: one-at-a-time image serving, vote submission, and automatic label finalization.

**Why one image at a time:**
- Every "next" click fetches a fresh image from the DB at that exact moment
- Guarantees the participant never receives an already-finalized image
- Threshold is respected at fetch time — no stale images, no wasted votes
- 60/40 split is precise per image, not approximate per batch

- `findParticipantTeam` and `findValidationThreshold` are cached in Redis since they never change during the competition — reducing effective DB queries per click from 4 to 2, cutting load in half

**Image serving logic (per request):**
1. Fetch participant's team — from Redis cache
2. Fetch threshold from `config` — from Redis cache
3. Count participant's validation history → `{ ownCount, otherCount }`
4. Decide pool using ratio logic (pure logic, no DB):
   ```
   if ownCount / (ownCount + otherCount + 1) < 0.6 → pick from own team
   else → pick from other teams
   ```
5. Fetch ONE image from chosen pool — single query applying all 3 exclusion filters:
   - Not already voted on by this participant
   - Vote count strictly less than threshold
   - `label.validated = false` — not already finalized

**Finalization logic:**
- Triggered automatically inside `submitVote` — no separate endpoint needed
- After every vote insert, the vote count is checked against the threshold
- If reached: majority vote is computed (pure logic) and Label module is called to update the label and mark it as validated


### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `getNextImage` | `compId`, `participantId` | `{ id, filepath }` |
| `submitVote` | `imageId`, `validatorId`, `label` | `{ validation_id, label }` |
| `getPendingValidations` | `compId` | `{ images[ ], total }` |

### APIs

**Endpoints**
- `GET    /competitions/:compId/validations/next` — Returns the next single eligible image for the participant — respects 60/40 split, threshold cap, and excludes finalized images
- `POST   /images/:imageId/validations` — Participant submits a validation vote — automatically finalizes label if threshold is reached
- `GET    /competitions/:compId/validations/pending` — Returns all images still pending final validation

**Controller**
- `handleGetNextImage(compId, participantId)`
- `handleSubmitVote(imageId)`
- `handleGetPendingValidations(compId)`

**Service**
- `getNextImage(compId, participantId)`
  - → `findParticipantTeam(compId, participantId)` — cached in Redis
  - → `findValidationThreshold(compId)` — cached in Redis
  - → `countParticipantValidations(participantId)` — gets `{ ownCount, otherCount }` from `label_validations`
  - → decide pool based on 60/40 ratio (pure logic, no DB):
    ```
    if ownCount / (ownCount + otherCount + 1) < 0.6 → own team
    else → other teams
    ```
  - → `findNextFromOwnTeam(compId, teamId, participantId, threshold)` or `findNextFromOtherTeams(compId, teamId, participantId, threshold)`
  - → return `{ id, filepath }`
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
- `findParticipantTeam(compId, participantId)` — cached in Redis, never changes during competition
- `findValidationThreshold(compId)` — cached in Redis, never changes during competition
- `countParticipantValidations(participantId)` — returns `{ ownCount, otherCount }` from `label_validations` joined with `image` and `team`
- `findNextFromOwnTeam(compId, teamId, participantId, threshold)` — single query excluding: already voted by participant + vote count >= threshold + `label.validated = true`
- `findNextFromOtherTeams(compId, teamId, participantId, threshold)` — same single query exclusion logic
- `insertVote(imageId, validatorId, label)`
- `countVotesForImage(imageId)`
- `findLabelByImageId(imageId)`
- `findVotesByLabelId(labelId)`
- `findPendingByComp(compId)`

### Dependencies
- `label`, `label_validations`, `image`, `team`, `config` tables
- **Redis** — caches `findParticipantTeam` and `findValidationThreshold` to reduce DB load
- **Label module** — `submitVote` automatically calls `LabelService.updateLabel` and `LabelService.setLabelValidated` when threshold is reached to persist and finalize the majority vote result