---
sidebar_position: 9
---

# Validation

## Overview

Handles the participant voting workflow for finalizing image labels. Uses a **round-robin distribution** to assign each image to multiple teams (threshold times). Participants fetch their team's validation queue, submit votes, and labels are auto-finalized via majority vote when the threshold is reached.

---

### Responsibility

Manages the full validation lifecycle: round-robin assignment generation, vote submission, skip handling, and automatic label finalization when the vote+skip threshold is met. Cross-module dependency on Label Service for persisting finalized results.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `generateAssignments` | `compId` | `{ success: true }` |
| `getValidationList` | `compId`, `participantId` | `{ image_ids[ ] }` |
| `submitVote` | `imageId`, `validatorId`, `label` | `{ validation_id, label }` |
| `skipImage` | `imageId`, `participantId` | `{ skip_count, threshold, auto_validated }` |
| `getPendingValidations` | `compId` | `{ images[ ], total }` |

### APIs

**Endpoints**
- `POST   /api/v1/competitions/{comp_id}/validations/generate` — Generate round-robin validation assignments — host only
- `GET    /api/v1/competitions/{comp_id}/validations/list` — Get validation queue for current participant
- `POST   /api/v1/images/{image_id}/validations` — Submit a validation vote
- `POST   /api/v1/images/{image_id}/validations/skip` — Skip an image in the queue
- `GET    /api/v1/competitions/{comp_id}/validations/pending` — Returns all images still pending final validation

**Controller**
- `handleGenerateAssignments(compId)`
- `handleGetValidationList(compId, participantId)`
- `handleSubmitVote(imageId)`
- `handleSkipImage(imageId)`
- `handleGetPendingValidations(compId)`

**Service**
- `generateAssignments(compId)`
  - → `fetchAllTeams(compId)`
  - → `fetchAllCompetitionImages(compId)`
  - → rounds-robin: assign each image threshold times across teams
  - → store each team's assignment in Redis
- `getValidationList(compId, participantId)`
  - → `findParticipantTeam(compId, participantId)`
  - → `getTeamAssignments(teamId)` from Redis
  - → `filterUnvalidatedImages(imageIds)`
  - → deterministic shuffle per participant
- `submitVote(imageId, validatorId, label)`
  - → `insertVote(imageId, validatorId, label)`
  - → count votes for this image
  - → if vote_count + skip_count >= threshold:
      - → `computeMajorityVote(votes)`
      - → `LabelService.updateLabel(imageId, finalLabel)`
      - → `LabelService.validateLabel(imageId)`
- `skipImage(imageId, participantId)`
  - → remove from team's assignment
  - → increment skip count
  - → if vote_count + skip_count >= threshold:
      - → auto-validate with majority vote or original label
- `getPendingValidations(compId)`
  - → `findPendingByComp(compId)` — images not yet finalized

**Repository**
- `fetchAllTeams(compId)`
- `fetchAllCompetitionImages(compId)`
- `findValidationThreshold(compId)` — reads from `config`
- `storeTeamAssignments(teamId, imageIds)` — in Redis
- `getTeamAssignments(teamId)` — from Redis
- `findParticipantTeam(compId, participantId)`
- `filterUnvalidatedImages(imageIds)`
- `insertVote(imageId, validatorId, label)`
- `findLabelByImageId(imageId)`
- `findVotesByLabelId(labelId)`
- `countVotesForImage(imageId)`
- `incrementSkipCount(imageId)`
- `removeFromTeamAssignment(teamId, imageId)`
- `findPendingByComp(compId)`

### Dependencies
- `label`, `label_validations`, `image`, `team`, `config` tables
- **Label Service** — `submitVote` calls `LabelService.updateLabel` and `LabelService.validateLabel` to persist the majority vote result
- **Redis** — stores team validation assignments (required for assignment workflow)
- **Validation Cache** — optional Redis-backed cache for validation data

### Validation Flow

```
1. Host: POST /validations/generate
   └─ Round-robin: image 1 → team A, team B, team C (threshold=3)
   └─ Stored in Redis: team_A → [1,4,7,...], team_B → [1,2,5,...]

2. Participant: GET /validations/list
   └─ Fetches team's assignment from Redis
   └─ Filters out already-validated images
   └─ Deterministic shuffle per participant ID

3. Participant: POST /images/{id}/validations
   └─ Records vote
   └─ If vote+skip >= threshold:
       ├─ Compute majority vote
       ├─ Update label via Label Service
       └─ Mark label validated

4. Participant: POST /images/{id}/validations/skip
   └─ Removes from queue
   └─ If vote+skip >= threshold:
       └─ Auto-validate

5. Completion: validation queue drains as images reach threshold
```

### Auto-Finalization

No separate `finalizeLabel` endpoint exists. Labels are automatically finalized inside `submitVote()` and `skipImage()` when the combined count (votes + skips) reaches the configured threshold from `config.max_validations` (default: 5).
