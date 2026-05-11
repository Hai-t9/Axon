---
sidebar_position: 13
---

# Leaderboard

## Overview

Standalone read module that computes and returns team rankings from evaluation scores already stored in the DB. The leaderboard is phase-gated and only becomes visible starting from Phase 3 (Model Submission). Rankings are computed on the fly every time the endpoint is called, with support for result limits and tie handling.

---

## Responsibility

No writes to the DB. Joins evaluation scores to teams via submitted models, picks the best score per team (highest score, earliest submission breaks ties), assigns ranks (teams with identical scores share the same rank), and returns a sorted list. Enforces phase gating - leaderboard remains empty until Model Submission phase is reached. The `limit` query param lets the caller cap how many entries are returned (1-100).

---

## Phase Gating

| Phase | Phase Label | Leaderboard Visible |
|-------|-------------|-------------------|
| 0 | Label | No (empty results) |
| 1 | Validation | No (empty results) |
| 2 | Evaluation | No (empty results) |
| 3+ | Model Submission+ | Yes (populated) |

---

## Inputs / Outputs

| Function | Input | Output |
|---------|--------|--------|
| `getLeaderboard` | `compId`, `type` (optional), `limit` (optional) | `{ entries[{rank, team, score, submitted_at, models_submitted, ...}], total_teams, type, phase, phase_label, last_updated }` |

---

## APIs

### Endpoints

- `GET /competitions/:compId/leaderboard`
  - Query parameters:
    - `type` (optional, default: "public") - leaderboard type/view
    - `limit` (optional, 1-100) - max number of entries to return
  - Returns ranked list of teams with scores and metadata
  - All authenticated users can call this

### Controller

- `getLeaderboard(compId, authorization, type, limit, auth_service, leaderboard_service)`
  - Validates authorization (all authenticated users)
  - Calls service with comp_id, type, and limit
  - Returns `LeaderboardResponse`

---

## Service

### getLeaderboard(compId, leaderboard_type, limit)

1. Call `_get_phase_info(compId)` via `PhaseService`
2. Get current phase and phase label
3. Check phase gate: if phase < 3 (Model Submission), return empty leaderboard
4. Call `findBestScorePerTeam(compId, limit)` from repository
5. Assign ranks:
   - Iterate through sorted entries
   - Assign rank based on position, but teams with same score share same rank
   - Example: entries with scores [95, 95, 90, 90, 90, 85] get ranks [1, 1, 3, 3, 3, 6]
6. Apply limit if provided
7. Return response with:
   - entries (ranked)
   - total_teams (unique count in results)
   - type (leaderboard_type)
   - phase (current phase number)
   - phase_label (human-readable phase name)
   - last_updated (current datetime)

---

## Repository

### findBestScorePerTeam(compId, limit)

**SQL Logic:**
1. Join `evaluation` → `model` → `team`
2. Filter by `model.competition_id == compId`
3. Order by:
   - `evaluation.score DESC` (highest score first)
   - `model.submitted_at DESC` (earliest submission first for tiebreak)
4. Iterate results and keep only the first (best) entry per team
5. Compute `models_submitted` count per team (from all models, not just best)
6. Return list of best entries sorted by score and submission time

**Output per entry:**
```json
{
  "team": {
    "id": "uuid",
    "name": "Team Name"
  },
  "score": 95.5,
  "submitted_at": "2025-05-10T14:30:00",
  "evaluated_at": "2025-05-10T14:45:00",
  "models_submitted": 3
}
```

---

## Response Schema

### LeaderboardResponse

```json
{
  "entries": [
    {
      "rank": 1,
      "team": {
        "id": "uuid-1",
        "name": "Team Alpha"
      },
      "score": 95.5,
      "submitted_at": "2025-05-10T14:30:00",
      "models_submitted": 3,
      "accuracy": null,
      "precision": null,
      "recall": null,
      "f1_score": null,
      "protocol": null
    },
    {
      "rank": 1,
      "team": {
        "id": "uuid-2",
        "name": "Team Beta"
      },
      "score": 95.5,
      "submitted_at": "2025-05-10T14:35:00",
      "models_submitted": 2,
      "accuracy": null,
      "precision": null,
      "recall": null,
      "f1_score": null,
      "protocol": null
    },
    {
      "rank": 3,
      "team": {
        "id": "uuid-3",
        "name": "Team Gamma"
      },
      "score": 92.0,
      "submitted_at": "2025-05-10T13:45:00",
      "models_submitted": 5,
      "accuracy": null,
      "precision": null,
      "recall": null,
      "f1_score": null,
      "protocol": null
    }
  ],
  "total_teams": 3,
  "type": "public",
  "phase": "3",
  "phase_label": "Model Submission",
  "last_updated": "2025-05-11T10:15:30"
}
```

---

## Rank Assignment Logic

Teams with identical scores share the same rank. The next rank skips accordingly.

**Example:**
```
Score | Team         | Rank
------|--------------|-----
95.5  | Team Alpha   | 1
95.5  | Team Beta    | 1
92.0  | Team Gamma   | 3
92.0  | Team Delta   | 3
90.0  | Team Epsilon | 5
```

---

## Tiebreak Rules

When multiple teams have the same score:
1. **Primary**: Higher score wins (sorted descending)
2. **Secondary**: Earlier submission time wins (sorted descending by submitted_at)
3. **Final**: Teams with identical score and submission time both receive the same rank

---

## Query Parameters

| Parameter | Type | Default | Validation | Purpose |
|-----------|------|---------|------------|---------|
| `type` | string | "public" | - | Leaderboard type/view selector |
| `limit` | integer | null | 1-100 | Max entries to return; null = no limit |

---

## Database Tables Involved

- `evaluation` - scores and evaluation timestamps
- `model` - submitted models with submission time and competition_id
- `team` - team metadata (id, name)

---

## Key Behaviors

1. **Computed Fresh**: Leaderboard is recalculated on every request (no caching)
2. **Phase Gated**: Empty results before Phase 3 (Model Submission)
3. **Best Per Team**: Only the highest-scoring model per team is ranked
4. **Models Submitted Count**: Includes ALL models submitted by team, not just the best one
5. **Tie Handling**: Teams with same score get same rank, next rank is not consecutive
6. **Optional Metrics**: Fields like accuracy, precision, recall, f1_score are defined in schema but may be null (populated by future enhancement or external evaluation source)
7. **Last Updated**: Always set to current datetime when called (no caching)

---

## API Call Example

**Request:**
```
GET /competitions/550e8400-e29b-41d4-a716-446655440000/leaderboard?type=public&limit=10
Authorization: Bearer <token>
```

**Response (Phase >= 3):**
```json
{
  "entries": [ ... ],
  "total_teams": 45,
  "type": "public",
  "phase": "3",
  "phase_label": "Model Submission",
  "last_updated": "2025-05-11T10:15:30"
}
```

**Response (Phase < 3):**
```json
{
  "entries": [],
  "total_teams": 0,
  "type": "public",
  "phase": "1",
  "phase_label": "Validation",
  "last_updated": "2025-05-11T10:15:30"
}
```

---

## Final System Definition

> A phase-gated read-only leaderboard that computes and returns team rankings by best evaluation score, with support for result limits, tie handling via submission time, and transparent phase visibility to clients.
