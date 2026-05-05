---
sidebar_position: 1
---

# Competition

## Overview

Manages competition creation, configuration, and basic lifecycle management. Responsible for storing competition metadata, defining evaluation protocols, setting validation parameters, and managing competition deletion. The Competition Service delegates all phase-related operations to the dedicated Phase Service.

---

### Responsibility

Handles CRUD operations for competition entities and configuration. Restricted to host role for creation, update, and deletion. Provides competition retrieval for all authenticated users. Phase management is delegated to the Phase Service.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `createCompetition` | `hostId`, `name`, `description`, `config` | `{ id, name, description, config, status, created_at }` |
| `getCompetition` | `compId` | `{ id, name, description, config, status, created_at, updated_at }` |
| `getCompetitions` | `filters` (optional) | `{ competitions[ ], total, page }` |
| `updateCompetition` | `compId`, `updates` | `{ id, ...updates, updated_at }` |
| `deleteCompetition` | `compId` | `{ deleted: true, id }` |
| `getCompetitionConfig` | `compId` | `{ id, config: { ...all_settings } }` |
| `updateCompetitionConfig` | `compId`, `configUpdates` | `{ id, config: { ...updated_config } }` |

### APIs

**Endpoints**

- `POST   /competitions` — Create a new competition — host only
- `GET    /competitions` — List all competitions — supports pagination and filters
- `GET    /competitions/:compId` — Retrieve a specific competition by ID
- `PUT    /competitions/:compId` — Update competition metadata — host only
- `DELETE /competitions/:compId` — Delete a competition — host only
- `GET    /competitions/:compId/config` — Retrieve full competition configuration
- `PUT    /competitions/:compId/config` — Update competition configuration — host only

**Controller**

- `handleCreateCompetition()`
- `handleGetCompetitions()`
- `handleGetCompetition(compId)`
- `handleUpdateCompetition(compId)`
- `handleDeleteCompetition(compId)`
- `handleGetCompetitionConfig(compId)`
- `handleUpdateCompetitionConfig(compId)`

**Service**

- `createCompetition(hostId, name, description, config)`
  - → `validateCompetitionName(name)` — ensure unique, non-empty
  - → `validateConfig(config)` — validate all configuration fields
  - → `insertCompetition(hostId, name, description, config)`
  - → return created competition
- `getCompetition(compId)` → `findCompetitionById(compId)`
- `getCompetitions(filters)`
  - → `findAllCompetitions(filters)` — supports status, created_by, date range filters
  - → return paginated results
- `updateCompetition(compId, updates)`
  - → `validateUpdates(updates)` — ensure only allowed fields are updated
  - → `modifyCompetition(compId, updates)`
  - → return updated competition
- `deleteCompetition(compId)`
  - → `checkCompetitionEmpty(compId)` — ensure no dependent data or cascade delete
  - → `removeCompetition(compId)`
  - → return deletion confirmation
- `getCompetitionConfig(compId)` → `findConfigByCompetitionId(compId)`
- `updateCompetitionConfig(compId, configUpdates)`
  - → `validateConfigUpdates(configUpdates)` — validate all settings
  - → `modifyConfig(compId, configUpdates)`
  - → return updated config

**Repository**

- `insertCompetition(hostId, name, description, config)`
- `findCompetitionById(compId)`
- `findAllCompetitions(filters)` — supports pagination
- `modifyCompetition(compId, updates)`
- `removeCompetition(compId)`
- `findConfigByCompetitionId(compId)`
- `modifyConfig(compId, configUpdates)`

### Dependencies

- `competition`, `config` tables
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
  id: UUID,
  host_id: UUID,
  name: string,
  description: string,
  status: enum('active' | 'archived'),
  config: JSON (see CompetitionConfig below),
  created_at: timestamp,
  updated_at: timestamp
}
```

**Competition Config**
```
{
  competition_id: UUID,
  protocol_type: enum('standard' | 'loto' | 'toto'),
  num_folds: integer (default: 5),
  validation_queue_size: integer (default: 50),
  team_validation_split: { own: 60, other: 40 },
  image_format_requirements: { formats: ['JPEG', 'PNG'], max_size_mb: 10 },
  min_images_per_team: integer (default: 10),
  min_votes_per_label: integer (default: 3)
}
```
