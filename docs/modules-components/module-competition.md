---
sidebar_position: 1
---

# Competition

## Overview

Manages competition creation, configuration, and lifecycle management. Responsible for storing competition metadata (name, description, launch date), defining evaluation protocols, setting validation parameters, and managing competition deletion. Config is stored in a **separate `config` table** (1:1 with competition, UUID PK). The Competition Service delegates all phase-related operations to the dedicated Phase Service.

---

### Responsibility

Handles CRUD operations for competition entities and their config. Restricted to host role for creation, update, and deletion. On creation, automatically creates a host `Role` entry linking the creating user to the competition. Provides join/leave flows via invitation links. Phase management is delegated to the Phase Service.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `createCompetition` | `hostId`, `name`, `description`, `launchDate`, `config` | `{ id, name, description, launch_date, config }` |
| `getCompetition` | `compId` | `{ id, name, description, launch_date, invitation_link, config }` |
| `listCompetitions` | `page`, `limit` | `{ items[ ], total, page, limit }` |
| `listMyCompetitions` | `user` | `{ items[ { id, name, description, role, team_id, team_name } ] }` |
| `joinCompetition` | `userId`, `invitationLink` | `{ id, name, description, role, team_id, team_name }` |
| `leaveCompetition` | `userId`, `compId` | `{ success }` |
| `updateCompetition` | `compId`, `updates` | `{ id, name, description, launch_date }` |
| `deleteCompetition` | `compId` | `{ deleted: true, id }` |
| `getCompetitionConfig` | `compId` | `{ id, labels, data_ex, scoring_ex, ...all_settings }` |
| `updateCompetitionConfig` | `compId`, `configUpdates` | `{ id, competition_id, ...updated_config }` |

### APIs

**Endpoints**

- `POST   /api/v1/competitions` — Create a new competition — host only (auto-creates host Role)
- `GET    /api/v1/competitions` — List all competitions — supports pagination
- `GET    /api/v1/competitions/mine` — List competitions the current user belongs to
- `POST   /api/v1/competitions/join` — Join a competition via invitation link
- `POST   /api/v1/competitions/{competition_id}/leave` — Leave a competition
- `GET    /api/v1/competitions/{competition_id}` — Retrieve a specific competition by ID
- `GET    /api/v1/competitions/{competition_id}/my-team` — Get current user's team in competition
- `PUT    /api/v1/competitions/{competition_id}` — Update competition metadata — host only
- `DELETE /api/v1/competitions/{competition_id}` — Delete a competition — host only
- `GET    /api/v1/competitions/{competition_id}/config` — Retrieve full competition configuration
- `PUT    /api/v1/competitions/{competition_id}/config` — Update competition configuration — host only

**Controller**

- `handleCreateCompetition()`
- `handleListCompetitions()`
- `handleListMyCompetitions()`
- `handleJoinCompetition()`
- `handleLeaveCompetition()`
- `handleGetCompetition(compId)`
- `handleGetMyTeam(compId)`
- `handleUpdateCompetition(compId)`
- `handleDeleteCompetition(compId)`
- `handleGetCompetitionConfig(compId)`
- `handleUpdateCompetitionConfig(compId)`

**Service**

- `createCompetition(hostId, payload)`
  - → `validateName(name)` — ensure unique
  - → `create({ name, description, launch_date })` — insert Competition row
  - → `createConfig(competition_id, config_data)` — insert Config row
  - → `createRole(hostId, competition_id, 'host')` — grant host role
  - → return created competition (with config relation loaded)
- `getCompetition(compId)` → `findCompetitionById(compId)`
- `listCompetitions(page, limit)`
  - → `findAllCompetitions(offset, limit)`
  - → `countCompetitions()`
  - → return paginated results
- `listMyCompetitions(user)` → find all competitions user has a role in
- `joinCompetition(userId, invitationLink)` → find by link, create participant role
- `leaveCompetition(userId, compId)` → remove role
- `updateCompetition(compId, updates)`
  - → only allow `name`, `description`, `launch_date`
  - → return updated competition
- `deleteCompetition(compId)` → cascades to config, roles, teams, images
- `getCompetitionConfig(compId)` → find config, raise NotFound if missing
- `updateCompetitionConfig(compId, configUpdates)` → find or create config, update

**Repository**

- `getById(compId)` → Competition
- `getByName(name)` → Competition | None
- `listCompetitions(offset, limit)` → Competition[]
- `countCompetitions()` → int
- `create(data)` → Competition
- `update(competition, updates)` → Competition
- `delete(competition)` → None
- `createConfig(competition_id, data)` → Config
- `getConfig(competition_id)` → Config | None
- `updateConfig(config, updates)` → Config
- `createRole(user_id, competition_id, role)` → Role

### Dependencies

- `competition` table — stores `id (UUID)`, `name`, `description`, `launch_date`, `invitation_link`
- `config` table — stores all competition settings (separate 1:1 table, UUID PK)
- `role` table — host/participant/staff assignments created on competition creation
- **Phase module** — delegates all phase management operations to Phase Service
- **Teams module** — competitions have many teams
- **Image module** — competitions have many images
- **Label module** — images in a competition have labels
- **Validation module** — reads competition config for validation limits
- **Dashboard module** — reads competition info for dashboard display

### Data Model

**Competition Entity**
```
{
  id: UUID (PK),
  name: string (unique, required),
  description: text (nullable),
  launch_date: date (nullable),
  invitation_link: string (unique, nullable)
}
```

No `host_id` — host assignment is stored in the `role` table (user_id + competition_id + 'host').
No `status` column — competition lifecycle is tracked via `PhaseLog.current_phase`.
No embedded config — config lives in the separate `config` table.

**Config Table (1:1 with Competition)**
```
{
  id: UUID (PK),
  competition_id: UUID (unique FK → competition.id),
  labels: JSON (nullable),
  data_ex: string (nullable),
  scoring_ex: string (nullable),
  overview: string (nullable),
  terms_conditions: string (nullable),
  data_md: string (nullable),
  data_format: JSON (nullable) — list of accepted formats,
  evaluation: string (nullable) — protocol: "standard" | "loto" | "toto",
  duplicate_threshhold: float (nullable),
  max_validations: int (nullable),
  model_spec: JSON (nullable) — Docker submission requirements
}
```
