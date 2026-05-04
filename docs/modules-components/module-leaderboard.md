# Module Breakdown — Leaderboard

![Dashboard Diagram](../../static/diagrams/leaderboard.png)

## Overview

Standalone read module that computes and returns team rankings from scores already stored in the DB. Displayed at the end of the competition. Rankings are computed on the fly every time the endpoint is called.

---

### Responsibility
No writes to the DB. Joins evaluation scores to teams, picks the best score per team (since teams can have multiple submissions), and sorts them into a ranked list. The `limit` query param lets the caller cap how many entries are returned.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `getLeaderboard` | `compId`, `limit` (optional) | `{ entries[ rank, team, score, submitted_at ], total_teams, last_updated }` |

### APIs

**Endpoints**
- `GET    /competitions/:compId/leaderboard` — Returns ranked list of teams with score, submission time, and rank — supports optional limit

**Controller**
- `handleGetLeaderboard(compId)`

**Service**
- `getLeaderboard(compId, limit)` → `findBestScorePerTeam(compId, limit)`

**Repository**
- `findBestScorePerTeam(compId, limit)` — joins `evaluation → model → team`, picks best score per team, sorted by score descending, assigns ranks

### Dependencies
- `evaluation`, `model`, `team` tables