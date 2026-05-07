---
sidebar_position: 12
---

# Dashboard

![Dashboard Diagram](../../static/diagrams/dashboard.png)

## Overview

Passive read module that aggregates competition state from multiple tables and returns a unified dashboard view. Supports Redis caching to avoid redundant queries on frequent loads. Responses are role-aware: hosts and staff receive the full dashboard; participants receive a limited view scoped to their team.

---

### Responsibility
No writes to the DB. When a host or staff requests the dashboard fresh, it pulls from 4 tables and saves the result to Redis. Participants receive a filtered response with team-only stats and do not use cached payloads. The host can clear the cache at any time to force a fresh computation.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `getDashboard` | `compId` | `{ phase_info, config, image_stats, team_info }` (host/staff full) |
| `getParticipantDashboard` | `compId`, `participantId` | `{ phase_info, config, image_stats, team_info }` (participant limited) |
| `getCachedDashboard` | `compId` | `{ cached_at, data }` |
| `clearDashboardCache` | `compId` | `{ cleared: true }` |

### APIs

**Endpoints**
- `GET    /competitions/:compId/dashboard` — Returns full dashboard for host/staff; participant receives limited view
- `GET    /competitions/:compId/dashboard/cache` — Returns a previously cached version of the full dashboard with its timestamp — host/staff only
- `DELETE /competitions/:compId/dashboard/cache` — Clears the cached dashboard, forcing a fresh computation on next load — host only

**Controller**
- `handleGetDashboard(compId)`
  - role check: host, participant, staff
  - host/staff → full dashboard
  - participant → limited dashboard
- `handleGetCachedDashboard(compId)` — host/staff only
- `handleClearDashboardCache(compId)` — host only

**Service**
- `getDashboard(compId)` (host/staff)
  - → `findPhaseInfo(compId)`
  - → `findConfig(compId)`
  - → `findImageStats(compId)`
  - → `findTeamInfo(compId)`
  - → save result to Redis `dashboard:${compId}`
  - → return data
- `getParticipantDashboard(compId, participantId)`
  - → `findPhaseInfo(compId)`
  - → `findConfig(compId)` (filtered fields only)
  - → `findTeamForParticipant(compId, participantId)`
  - → `findTeamImageStats(teamId)`
  - → return data (no cache)
- `getCachedDashboard(compId)` → `redis.get(dashboard:${compId})` → return `{ cached_at, data }`
- `clearDashboardCache(compId)` → `redis.del(dashboard:${compId})` → return `{ cleared: true }`

**Repository**
- `findPhaseInfo(compId)` — reads from `phase_log`
- `findConfig(compId)` — reads from `config`
- `findImageStats(compId)` — counts total / verified / on-hold from `image`
- `findTeamInfo(compId)` — reads from `team`
- `findTeamForParticipant(compId, participantId)` — finds participant team from `team.user_ids`
- `findTeamImageStats(teamId)` — counts total / verified / on-hold for a single team

### Participant response constraints
- `phase_info`: `competition_id`, `current_phase`, `phase_dates`
- `config`: `labels`, `data_ex`, `overview`, `terms_conditions`, `data_md`, `data_format`
- `image_stats`: team-only `total`, `verified`, `on_hold`
- `team_info`: participant team only (`id`, `name`, `comp_id`, `user_ids`)
- Must NOT include: `scoring_ex`, `evaluation`, `duplicate_threshhold`, `max_validations`, global image stats, or all teams

### Dependencies
- `phase_log`, `config`, `image`, `team` tables
- Redis (cache read/write/delete — no repo layer involved)
