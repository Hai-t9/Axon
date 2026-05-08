---
sidebar_position: 3
---

# Teams

## Overview

Manages competition participants and team administration. Handles team registration, member management, and participation tracking. Members are stored as a JSON array of user IDs on the Team record — no separate members table.

---

### Responsibility

Handles full CRUD operations on teams. Manages team profiles, member assignments (via `user_ids` JSON column), and participation history. Restricted to host/staff for team creation and deletion.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `createTeam` | `compId`, `name`, `userIds` | `{ id, comp_id, name, user_ids }` |
| `getTeam` | `teamId` | `{ id, comp_id, name, user_ids }` |
| `getTeamsByCompetition` | `compId`, `page`, `limit` | `{ teams[ ], total }` |
| `updateTeam` | `teamId`, `updates` | `{ id, ...updates }` |
| `deleteTeam` | `teamId` | `{ deleted: true, id }` |
| `addMember` | `teamId`, `userId` | `{ id, comp_id, name, user_ids }` |
| `removeMember` | `teamId`, `userId` | `{ id, comp_id, name, user_ids }` |
| `getMembers` | `teamId` | `{ members[ { id, fullname, email } ] }` |
| `getTeamStatistics` | `teamId` | `{ total_members, images_uploaded, models_submitted }` |

### APIs

**Endpoints**

- `POST   /competitions/:compId/teams` — Create a new team — host/staff only
- `GET    /competitions/:compId/teams` — List all teams in competition — supports pagination
- `GET    /teams/:teamId` — Retrieve team details by ID
- `PUT    /teams/:teamId` — Update team metadata — host/staff only
- `DELETE /teams/:teamId` — Delete a team — host only
- `GET    /teams/:teamId/members` — List team members (resolved from `user_ids`)
- `POST   /teams/:teamId/members` — Add member to team — host/staff only
- `DELETE /teams/:teamId/members/:userId` — Remove member from team — host/staff only
- `GET    /teams/:teamId/statistics` — Get team performance statistics

**Controller**

- `handleCreateTeam()`
- `handleGetTeam(teamId)`
- `handleGetTeamsByCompetition(compId)`
- `handleUpdateTeam(teamId)`
- `handleDeleteTeam(teamId)`
- `handleAddTeamMember(teamId, userId)`
- `handleRemoveTeamMember(teamId, userId)`
- `handleGetTeamMembers(teamId)`
- `handleGetTeamStatistics(teamId)`

**Service**

- `createTeam(compId, name, userIds)`
  - → `validateTeamName(name)` — ensure unique within competition
  - → `normalizeUserIds(userIds)` — deduplicate, stringify UUIDs
  - → `create(compId, name, user_ids)`
  - → return created team
- `getTeam(teamId)` → `findTeamById(teamId)`
- `listTeams(compId, page, limit)`
  - → `findTeamsByCompetition(compId, offset, limit)`
  - → `countTeamsByCompetition(compId)`
  - → return paginated results
- `updateTeam(teamId, updates)`
  - → `getTeam(teamId)`
  - → `validateUpdates(updates)`
  - → `update(team, updates)`
  - → return updated team
- `deleteTeam(teamId)`
  - → `getTeam(teamId)`
  - → `delete(team)`
  - → return deletion confirmation
- `addMember(teamId, userId)`
  - → verify user exists
  - → check user not already in team
  - → append to `user_ids` JSON array
  - → return updated team
- `removeMember(teamId, userId)`
  - → verify user is in team
  - → remove from `user_ids` JSON array
  - → return updated team
- `getMembers(teamId)`
  - → read `user_ids` from team
  - → `findUsersByIds(userIds)` — resolve UUIDs to User records
  - → return user list
- `getTeamStatistics(teamId)`
  - → `countMembers(userIds)` — length of JSON array
  - → `countImagesByTeam(teamId)`
  - → `countModelsByTeam(teamId)`
  - → return aggregated statistics

**Repository**

- `getById(teamId)` → Team | None
- `getByName(compId, name)` → Team | None
- `listByCompetition(compId, offset, limit)` → Team[]
- `countByCompetition(compId)` → int
- `create(teamData)` → Team
- `update(team, updates)` → Team
- `delete(team)` → None
- `getUserById(userId)` → User | None
- `setTeamMembers(team, userIds)` → Team (writes `user_ids` JSON)
- `getTeamMembers(team)` → User[] (resolves UUIDs from `user_ids`)
- `countImagesByTeam(teamId)` → int
- `countModelsByTeam(teamId)` → int

### Dependencies

- `team` table only (no separate members table — membership stored in `user_ids` JSON column)
- `user` table — for resolving member UUIDs to user records
- **Competition module** — teams belong to competitions
- **Image module** — teams upload images
- **Model Submission Service** — teams submit models

### Data Model

**Team Entity**
```
{
  id: UUID,
  comp_id: UUID (FK → competition.id),
  name: string (unique per competition),
  user_ids: string[] (JSON — array of user UUIDs)
}
```

**User IDs** are stored as a JSON array of strings. Example: `["550e8400-...", "6ba7b810-..."]`. Members are resolved by querying the `user` table with these IDs.

**Team Statistics (Computed)**
```
{
  total_members: integer,
  images_uploaded: integer,
  models_submitted: integer
}
```
