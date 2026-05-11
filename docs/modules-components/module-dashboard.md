---
sidebar_position: 12
---

# Dashboard

## Overview

Passive read module that aggregates competition state from multiple tables and returns a unified dashboard view. Supports Redis caching to avoid redundant queries on frequent loads. Responses are role-aware: hosts and staff receive the full dashboard with all teams and global stats; participants receive a filtered view scoped to their team only.

---

## Responsibility

No writes to the DB. When a host or staff requests the dashboard fresh, it pulls from 4 core tables plus optional metadata, computes aggregations (device stats, label distribution, locations), and saves the result to Redis. Participants receive a filtered response with only their team's stats and do not use cached payloads. The host can clear the cache at any time to force a fresh computation.

---

## Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `getDashboard` | `compId` | `{ phase_info, config, image_stats, team_info, device_stats, label_distribution, locations }` (host/staff full) |
| `getParticipantDashboard` | `compId`, `participantId` | `{ phase_info, config, image_stats, team_info, device_stats, label_distribution, locations }` (participant limited) |
| `getCachedDashboard` | `compId` | `{ cached_at, data }` |
| `clearDashboardCache` | `compId` | `{ cleared: true }` |
| `getDashboardRole` | `participantId`, `compId` | `{ role }` |

---

## APIs

### Endpoints

- `GET /competitions/:compId/dashboard`
  - Returns full dashboard for host/staff; participant receives team-scoped view
  - All authenticated users can call this

- `GET /competitions/:compId/dashboard/role`
  - Returns the user's role for this competition
  - All authenticated users can call this

- `GET /competitions/:compId/dashboard/cache`
  - Returns a previously cached version of the full dashboard with its `cached_at` timestamp
  - Host and staff only

- `DELETE /competitions/:compId/dashboard/cache`
  - Clears the cached dashboard, forcing a fresh computation on next load
  - Host only

### Controller

- `get_dashboard(compId, authorization, auth_service, dashboard_service)`
  - Role check: host → full, staff → full, participant → team-scoped
  - Returns `DashboardResponse` or `DashboardParticipantResponse` based on role

- `get_dashboard_role(compId, authorization, auth_service)`
  - Returns user's role for this competition
  - Returns `RoleResponse { role: string | null }`

- `get_cached_dashboard(compId, authorization, auth_service, dashboard_service)`
  - Host/staff only
  - Returns `DashboardCachedResponse { cached_at, data }`

- `clear_dashboard_cache(compId, authorization, auth_service, dashboard_service)`
  - Host only
  - Returns `DashboardCacheClearResponse { cleared: true }`

### Service

#### getDashboard(compId)
- Call `PhaseService.getCurrentPhase(compId)`
- Call `findConfig(compId)`
- Call `findImageStats(compId)` - global across all teams
- Call `findTeamInfo(compId)` - fetch all teams
- For each team: call `findTeamImageStats(teamId)`, `findTeamDeviceStats(teamId)`, `findTeamLabelDistribution(teamId)`
- Call `findDeviceStats(compId)` - global device counts
- Call `findLabelDistribution(compId)` - global label counts
- Call `findLocations(compId)` - all GPS data
- Build response with serialized phase_info, config, image_stats, teams (with per-team stats), device_stats, label_distribution, locations
- Save to Redis with key `dashboard:{compId}`
- Return full payload

#### getParticipantDashboard(compId, participantId)
- Call `PhaseService.getCurrentPhase(compId)`
- Call `findConfig(compId)`
- Call `findTeamForParticipant(compId, participantId)`
- Call `findTeamImageStats(teamId)` - this team only
- Call `findTeamDeviceStats(teamId)` - this team only
- Call `findTeamLabelDistribution(teamId)` - this team only
- Call `findTeamLocations(teamId)` - this team's GPS data only
- Build response with serialized phase_info (full), config_participant (filtered), image_stats, team_info (single team with stats), device_stats (this team), label_distribution (this team), locations (this team)
- DO NOT cache - always compute fresh for participants

#### getCachedDashboard(compId)
- Call `cache.get_dashboard(compId)`
- If found, return `{ cached_at, data }`
- If not found, raise NotFoundError

#### clearDashboardCache(compId)
- Call `cache.clear_dashboard(compId)`
- Return `{ cleared: true }`

### Repository

#### Core Methods
- `findPhaseInfo(compId)` → `PhaseLog | None`
- `ensurePhaseInfo(compId)` → `PhaseLog` (creates default if missing)
- `findConfig(compId)` → `Config | None`
- `findTeamInfo(compId)` → `list[Team]`
- `findTeamForParticipant(compId, participantId)` → `Team | None` (looks up via user.email)

#### Image Stats Methods
- `findImageStats(compId)` → `{ total, verified, on_hold }` (competition-wide)
- `findTeamImageStats(teamId)` → `{ total, verified, on_hold }` (single team)

#### New: Device & Label Distribution Methods
- `findDeviceStats(compId)` → `{ device_name: count, ... }` (competition-wide)
- `findTeamDeviceStats(teamId)` → `{ device_name: count, ... }` (single team)
- `findLabelDistribution(compId)` → `{ label: count, ... }` (competition-wide)
- `findTeamLabelDistribution(teamId)` → `{ label: count, ... }` (single team)

#### New: Location/GPS Methods
- `findLocations(compId)` → `list[{ image_id, gps_info, location_metadata }]` (competition-wide)
- `findTeamLocations(teamId)` → `list[{ image_id, gps_info, location_metadata }]` (single team)

---

## Response Schemas

### Host/Staff Full Response (DashboardResponse)

```json
{
  "phase_info": {
    "competition_id": "uuid",
    "current_phase": "0",
    "phase_dates": { ... }
  },
  "config": {
    "id": "uuid",
    "competition_id": "uuid",
    "labels": { ... },
    "data_ex": "string",
    "scoring_ex": "string",
    "overview": "string",
    "terms_conditions": "string",
    "data_md": "string",
    "data_format": [ ... ],
    "evaluation": "string",
    "duplicate_threshhold": 0.95,
    "max_validations": 5
  },
  "image_stats": {
    "total": 1000,
    "verified": 750,
    "on_hold": 50
  },
  "team_info": {
    "items": [
      {
        "id": "uuid",
        "name": "Team A",
        "comp_id": "uuid",
        "user_emails": { "alice@example.com": 1, ... },
        "device_stats": { "iPhone 12": 45, "Samsung Galaxy": 30, ... },
        "label_distribution": { "cat": 50, "dog": 25, ... },
        "images_uploaded": 75
      },
      ...
    ],
    "total": 10
  },
  "device_stats": {
    "iPhone 12": 120,
    "Samsung Galaxy": 85,
    ...
  },
  "label_distribution": {
    "cat": 450,
    "dog": 350,
    ...
  },
  "locations": [
    {
      "image_id": "uuid",
      "gps_info": "40.7128,-74.0060",
      "location_metadata": {
        "make": "Apple",
        "model": "iPhone 12",
        "datetime": "2025-05-11T10:30:00"
      }
    },
    ...
  ]
}
```

### Participant Limited Response (DashboardParticipantResponse)

```json
{
  "phase_info": {
    "competition_id": "uuid",
    "current_phase": "0",
    "phase_dates": { ... }
  },
  "config": {
    "labels": { ... },
    "data_ex": "string",
    "overview": "string",
    "terms_conditions": "string",
    "data_md": "string",
    "data_format": [ ... ]
  },
  "image_stats": {
    "total": 75,
    "verified": 50,
    "on_hold": 5
  },
  "team_info": {
    "id": "uuid",
    "name": "Team A",
    "comp_id": "uuid",
    "user_emails": { "alice@example.com": 1, ... },
    "device_stats": { "iPhone 12": 45, "Samsung Galaxy": 30 },
    "label_distribution": { "cat": 50, "dog": 25 },
    "images_uploaded": 75
  },
  "device_stats": { "iPhone 12": 45, "Samsung Galaxy": 30 },
  "label_distribution": { "cat": 50, "dog": 25 },
  "locations": [
    {
      "image_id": "uuid",
      "gps_info": "40.7128,-74.0060",
      "location_metadata": {
        "make": "Apple",
        "model": "iPhone 12",
        "datetime": "2025-05-11T10:30:00"
      }
    },
    ...
  ]
}
```

### Cached Response (DashboardCachedResponse)

```json
{
  "cached_at": "2025-05-11T10:15:30",
  "data": { ... full DashboardResponse ... }
}
```

### Role Response (RoleResponse)

```json
{
  "role": "host" | "staff" | "participant" | null
}
```

---

## Participant Response Constraints

The participant view includes:

- `phase_info`: Complete (competition_id, current_phase, phase_dates)
- `config`: Filtered fields only:
  - labels
  - data_ex
  - overview
  - terms_conditions
  - data_md
  - data_format
  - Must NOT include: scoring_ex, evaluation, duplicate_threshhold, max_validations
- `image_stats`: Team-scoped only (total, verified, on_hold for this team)
- `team_info`: Single team object for participant's team (not array of all teams)
  - Includes per-team device_stats, label_distribution, images_uploaded
- `device_stats`: This team's devices only
- `label_distribution`: This team's labels only
- `locations`: This team's GPS data only

Participant cannot see:
- Other teams' information
- Global image stats
- Global device stats or label distribution
- Other teams' locations

---

## Caching Behavior

- **Host/Staff Dashboard**: Computed once, cached in Redis for all subsequent requests
- **Participant Dashboard**: Always computed fresh (no caching) - each participant gets custom-filtered response
- **Cache key**: `dashboard:{compId}`
- **Cache TTL**: 24 hours (or implementation default)

---

## Dependencies

- `phase_log` - current phase info (fetched via PhaseService)
- `config` - competition configuration
- `image` - image counts and status (verified, on_hold)
- `team` - team info and user mappings
- `image_metadata` - camera device info and GPS data (new)
- **Redis** - caching layer (host/staff dashboard only)

---

## Dependencies Diagram

```
Dashboard Module
├── PhaseService → phase_log
├── Config repository → config
├── Image repository → image, image_metadata
└── Team repository → team
```

---

## Key Behavior Notes

1. **Phase Info**: Fetched via PhaseService (ensures default is created if missing)
2. **Device Stats**: Aggregated from Image.device field
3. **Label Distribution**: Aggregated from Image.label field
4. **Locations**: Fetched from ImageMetadata where gps_info is not null
5. **User Lookup**: Uses user.email to find participant's team (case-insensitive match)
6. **Cache Strategy**: Only host/staff dashboard is cached; participants always get fresh computed data
7. **Team Stats Per-Team**: Each team has its own device_stats, label_distribution, images_uploaded
8. **Dual Aggregation**: Global stats (all teams) + per-team stats both provided

---

## Cache Management

| Operation | Who | Effect |
|-----------|-----|--------|
| GET /dashboard | Host/Staff | Serve cached if exists, else compute + cache |
| GET /dashboard | Participant | Always compute fresh (no cache) |
| GET /dashboard/cache | Host/Staff | Return cached data with timestamp |
| DELETE /dashboard/cache | Host | Clear cache, force fresh on next request |

---

## Final System Definition

> A role-aware, passively-read dashboard that aggregates competition state across teams, images, devices, and locations, with Redis caching for host/staff views and always-fresh computation for participant-scoped views.
