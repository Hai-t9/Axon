---
sidebar_position: 9
---

# Validation

## Overview

Handles the participant voting workflow for finalizing image labels. The validation module works in two distinct phases: a **generation phase** triggered once by the host, and a **validation phase** where participants validate images one at a time on the frontend.

The core idea is simple and mathematically guaranteed to validate all data: before validation starts, the system pre-generates a list of image IDs for each team using a **Round-Robin distribution**. Every image is included in the system flow until it reaches exactly `threshold` combined interactions (votes + skips).

When a participant requests their list, the team's master list is fetched from Redis, filtered to remove already-validated images, shuffled in memory using the participant's UUID as a deterministic seed, and returned to the frontend with image metadata (filepath, current label) all at once. The frontend loops through it locally, only calling the API to submit votes or skip images.

---

## Responsibility

Manages the full validation lifecycle in two phases:

---

## Phase 1 — Generation (host triggered, runs once)

To ensure 100% of images are validated and exactly hit the threshold, assignments are distributed evenly across all teams using a Round-Robin strategy.

---

### Step 1 — Fetch Data

- Fetch all `team_ids` in the competition
- Fetch all `image_ids` in the competition
- Fetch `threshold` from config (stored in `Config.max_validations`)

---

### Step 2 — Round-Robin Assignment

- Initialize an empty array for each team to hold assigned image IDs
- Loop through every image ID
- Assign each image repeatedly until it appears exactly `threshold` times in total across teams
- Distribution is done in a circular manner over teams (Round-Robin)

**Key Constraint:**
- Ensures workload is evenly distributed
- Ensures every image is guaranteed to reach validation threshold through participation

---

### Step 3 — Store in Redis

Store one master list per team only:

```
RPUSH validation:team:{teamId} ...imageIds
EXPIRE validation:team:{teamId} 86400
```

Example key:

```
validation:team:550e8400-e29b-41d4-a716-446655440000
```

- No per-participant keys needed
- Shuffling happens at request time in memory

---

## Phase 2 — Validation (participant driven)

Participants validate or skip images sequentially on the frontend.

---

### Step 1 — Fetch Validation List

```
GET /competitions/:compId/validations/list
```

**Request:**
- No body required
- Authorization header with bearer token

**Response:**
```json
{
  "images": [
    {
      "image_id": "uuid-string",
      "filepath": "s3://bucket/path/to/image.jpg",
      "current_label": "cat"
    },
    ...
  ],
  "total": 42
}
```

**Backend Process:**
1. Find participant's team from their user ID
2. Fetch team's master list from Redis using `LRANGE 0 -1`
3. Filter out already-validated images (where `Label.validated == True`)
4. Apply deterministic shuffle using `participantId` as seed
5. Fetch image metadata (filepath, current label) from database
6. Return full list with metadata to frontend

---

### Step 2 — Frontend Loop

- Stores list locally in state
- Displays one image at a time
- No API call per image
- Calls API only when submitting votes or skipping

---

### Step 3 — Submit Vote

```
POST /images/:imageId/validations
```

**Payload:**
```json
{
  "label": "cat"
}
```

**Response:**
```json
{
  "validation_id": "integer-id",
  "label": "cat"
}
```

**Backend Process:**
1. Check if label already validated → if so, return error
2. Check if participant already voted on this image → if so, return error
3. Insert vote into `label_validations` table
4. Increment `vote_count` for image
5. Calculate `vote_count + skip_count` for image
6. If combined count >= threshold:
   - Fetch all votes for this image
   - Compute majority vote (ties broken alphabetically)
   - Update `Label.label` with majority
   - Set `Label.validated = True`

---

### Step 4 — Skip Image (NEW)

```
POST /images/:imageId/validations/skip
```

**Payload:**
```json
{}
```

**Response:**
```json
{
  "skip_count": 3,
  "threshold": 5,
  "auto_validated": false
}
```

**Backend Process:**
1. Find participant's team
2. Remove image from team's validation queue using `LREM` in Redis
3. Increment skip count in Redis key `validation:skip_count:{imageId}`
4. Calculate `vote_count + skip_count` for image
5. If combined count >= threshold:
   - If votes exist: compute majority vote and set as final label
   - If no votes: keep original label
   - Set `Label.validated = True`
   - Return `auto_validated: true`

**Skip Logic:**
- Image is immediately removed from this team's queue (other teams can still validate)
- Skip count is tracked globally across all teams
- Validation completes when `vote_count + skip_count >= threshold`, regardless of ratio
- If skips reach threshold before votes, image auto-validates with original label

---

### Step 5 — Finalization Logic

Triggered automatically inside `submitVote` or `skipImage`:

- Check if `vote_count + skip_count >= threshold`
- If true:
  - Fetch all actual votes
  - Compute majority label (ties broken alphabetically ascending)
  - Update final label in database
  - Mark label as validated (`Label.validated = True`)

---

## Completion Rule

An image is considered complete when:

```
vote_count + skip_count >= threshold
```

This is the ONLY correctness condition in the system.

---

## Redis Keys

| Key | Value | Operation | Set when |
|-----|-------|----------|----------|
| `validation:team:{teamId}` | List of imageIds | RPUSH | Generation Phase |
| `validation:skip_count:{imageId}` | Integer count | INCR | Image skipped |

---

## Redis Operations

- `RPUSH validation:team:{teamId} [imageIds...]` → store precomputed team list
- `LRANGE validation:team:{teamId} 0 -1` → fetch full list for participant
- `LREM validation:team:{teamId} 0 {imageId}` → remove skipped image from queue
- `INCR validation:skip_count:{imageId}` → increment skip count
- `GET validation:skip_count:{imageId}` → fetch current skip count

---

## API Calls Comparison

|  | One-at-a-time (old) | Full list (current) |
|--|--|--|
| Get images | 1000 | 1 |
| Submit votes | 1000 | 1000 |
| Skip images | 0 | 0-N |
| **Total** | **2000** | **1001 + skips** |

---

## Inputs / Outputs

| Function | Input | Output |
|---------|--------|--------|
| `generateAssignments` | `compId` | `{ success: true }` |
| `getValidationList` | `compId`, `participantId` | `{ images[{image_id, filepath, current_label}], total }` |
| `submitVote` | `imageId`, `validatorId`, `label` | `{ validation_id, label }` |
| `skipImage` | `imageId`, `participantId` | `{ skip_count, threshold, auto_validated }` |
| `getPendingValidations` | `compId` | `{ images[{id, filepath, label}], total }` |

---

## APIs

### Endpoints

- `POST /competitions/:compId/validations/generate`
  - Host only (requires host role)
  - Runs Round-Robin assignment generation and stores results in Redis
  - Returns `{ success: true }`

- `GET /competitions/:compId/validations/list`
  - Authenticated users only
  - Fetch team list from Redis
  - Filter unvalidated images
  - Shuffle using participantId seed
  - Return full list with image metadata (filepath, current label)
  - Returns `{ images: [...], total: N }`

- `POST /images/:imageId/validations`
  - Authenticated users only
  - Submit validation vote
  - Automatically increments vote counter and checks threshold
  - Returns `{ validation_id, label }`

- `POST /images/:imageId/validations/skip` (NEW)
  - Authenticated users only
  - Skip image and remove from team's queue
  - Automatically increments skip counter and checks threshold
  - Returns `{ skip_count, threshold, auto_validated }`

- `GET /competitions/:compId/validations/pending`
  - Authenticated users only
  - Returns images where `validated == False`
  - Returns `{ images[{id, filepath, label}], total }`

---

## Controller

- `handleGenerateAssignments(compId, authorization, auth_service, validation_service)`
- `handleGetValidationList(compId, authorization, auth_service, validation_service)`
- `submitVote(imageId, payload, authorization, auth_service, validation_service)`
- `skipImage(imageId, authorization, auth_service, validation_service)` (NEW)
- `handleGetPendingValidations(compId, authorization, auth_service, validation_service)`

---

## Service

### generateAssignments(compId)

- `fetchAllTeams(compId)`
- `fetchAllCompetitionImages(compId)`
- `findValidationThreshold(compId)`
- Initialize per-team buckets
- Round-Robin assign images until each appears `threshold` times in total
- Store per-team list in Redis
- Return `{ success: true }`

---

### getValidationList(compId, participantId)

- `findParticipantTeam(compId, participantId)`
- `getTeamAssignments(teamId)` from Redis
- `filterUnvalidatedImages(image_ids)` - exclude already-validated
- `deterministicShuffle(list, seed=participantId)`
- `fetchImageDetails(shuffled)` - get filepath and current label
- Return `{ images: [...], total: N }`

---

### submitVote(imageId, validatorId, label)

- `insertVote(imageId, validatorId, label)`
- `countVotesForImage(imageId)`
- `getSkipCount(imageId)`
- Check if `vote_count + skip_count >= threshold`
- If threshold reached:
  - Fetch votes via `findVotesByLabelId(labelId)`
  - Compute majority using `_compute_majority_vote(votes)`
  - Update label via `LabelService.updateLabel(imageId, finalLabel)`
  - Validate via `LabelService.validateLabel(imageId)`
- Return `{ validation_id, label }`

---

### skipImage(imageId, participantId) (NEW)

- `findParticipantTeam(compId, participantId)`
- `removeFromTeamAssignment(teamId, imageId)` - LREM in Redis
- `incrementSkipCount(imageId)` - INCR in Redis
- `getSkipCount(imageId)`
- `countVotesForImage(imageId)`
- Check if `vote_count + skip_count >= threshold`
- If threshold reached:
  - If votes exist: compute majority and update label
  - Set `Label.validated = True`
- Return `{ skip_count, threshold, auto_validated }`

---

### getPendingValidations(compId)

- `findPendingByComp(compId)` - fetch images where validated == False
- Return `{ images: [...], total: N }`

---

## Repository

### Core Methods

- `fetchAllTeams(compId)` → `list[Team]`
- `fetchAllCompetitionImages(compId)` → `list[UUID]`
- `findParticipantTeam(compId, participantId)` → `UUID | None`
- `findValidationThreshold(compId)` → `int | None` (from Config.max_validations)

### Redis/Cache Methods

- `storeTeamAssignments(teamId, imageIds)` → `bool` (RPUSH + EXPIRE)
- `getTeamAssignments(teamId)` → `list[UUID]` (LRANGE)
- `removeFromTeamAssignment(teamId, imageId)` → `int` (LREM count) (NEW)
- `incrementSkipCount(imageId)` → `int` (new count) (NEW)
- `getSkipCount(imageId)` → `int` (NEW)

### Vote & Label Methods

- `insertVote(imageId, validatorId, label)` → `LabelValidation | None`
- `countVotesForImage(imageId)` → `int`
- `findLabelByImageId(imageId)` → `Label | None`
- `findVotesByLabelId(labelId)` → `list[LabelValidation]`

### Filtering & Details Methods

- `filterUnvalidatedImages(imageIds)` → `list[UUID]` (NEW)
- `fetchImageDetails(imageIds)` → `dict[UUID, dict]` (NEW)
- `findPendingByComp(compId)` → `list[dict]`

---

## Database Tables

- `image` - core image data (filepath, team_id)
- `team` - team grouping with user_emails
- `label` - image label with `validated` flag and vote count
- `label_validations` - individual validator votes
- `config` - competition config with `max_validations` (threshold)
- `user` - participant data (id, email)

---

## Key Guarantees

### Correctness
All images reach exactly:

```
vote_count + skip_count >= threshold
```

### No over-validation
Never exceeds threshold

### Balanced distribution
Round-Robin ensures even workload distribution across teams

### Fast retrieval
Redis provides instant team-level lists (or in-memory fallback)

### Deterministic UX
Same participant always sees same order (seeded shuffle)

### Flexible completion (NEW)
Images complete via any combination of votes + skips, not just votes

### Queue management (NEW)
Skipped images are removed from team's queue but remain available to other teams

---

## Final System Definition

> A threshold-driven validation system with Redis-backed Round-Robin pre-distribution, deterministic per-user shuffling, and flexible skip handling for participant experience and image completion.

---

## Core Rule (MOST IMPORTANT)

```
Validation correctness is ONLY defined by:
vote_count + skip_count >= threshold
```

Everything else (Redis, Round-Robin, shuffle, skip handling) is optimization and UX enhancement.

---

## Frontend Behavior (Important)

Once the validation list is retrieved from the backend, the frontend does not make additional requests per image.

Instead:

- The full `images[]` list with metadata is stored in local state
- The UI simply iterates over the list sequentially
- Each step shows one image at a time for validation
- On user action (submit vote or skip), only the respective API is called
- The next image is taken from the already-loaded list

**Pseudo-flow:**

```pseudo
imageList = await GET /competitions/{compId}/validations/list

for image in imageList:
    display(image)
    
    if userSubmitsVote(image):
        POST /images/{image.id}/validations { label }
    else if userSkips(image):
        POST /images/{image.id}/validations/skip
    
    showNext()
```

When the list ends:

- The frontend shows a "Validation Complete" screen
- No further backend calls are required
- User can navigate away or start another validation session

---

### Key Idea

> The frontend is just a consumer of a preloaded list — it does not decide logic, it only iterates and submits votes or skips. The backend handles all threshold logic and auto-validation.
