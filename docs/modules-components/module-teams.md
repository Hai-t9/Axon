---
sidebar_position: 3
---

# Teams

## Overview

Manages competition participants and team administration. Handles team registration, member management, team metadata storage, and participation tracking across competition seasons. Provides organizational structure for team hierarchies and member roles within teams.

---

### Responsibility

Handles full CRUD operations on teams and team members. Manages team profiles, member assignments, team metadata, and participation history. Restricted to host/staff for team creation and deletion. Provides team information for all authenticated users.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `createTeam` | `compId`, `name`, `organization`, `metadata` | `{ id, competition_id, name, organization, created_at }` |
| `getTeam` | `teamId` | `{ id, name, organization, members[ ], metadata, created_at }` |
| `getTeamsByCompetition` | `compId` | `{ teams[ ], total, page }` |
| `updateTeam` | `teamId`, `updates` | `{ id, ...updates, updated_at }` |
| `deleteTeam` | `teamId` | `{ deleted: true, id }` |
| `addTeamMember` | `teamId`, `userId`, `role` | `{ team_id, user_id, role, joined_at }` |
| `removeTeamMember` | `teamId`, `userId` | `{ removed: true, team_id, user_id }` |
| `getTeamMembers` | `teamId` | `{ members[ { id, name, role, joined_at } ], total }` |
| `getTeamStatistics` | `teamId` | `{ total_members, images_uploaded, models_submitted, rank }` |

### APIs

**Endpoints**

- `POST   /competitions/:compId/teams` — Create a new team — host/staff only
- `GET    /competitions/:compId/teams` — List all teams in competition — supports pagination
- `GET    /teams/:teamId` — Retrieve team details by ID
- `PUT    /teams/:teamId` — Update team metadata — host/staff only
- `DELETE /teams/:teamId` — Delete a team — host only
- `GET    /teams/:teamId/members` — List team members
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

- `createTeam(compId, name, organization, metadata)`
  - → `validateTeamName(name)` — ensure unique within competition
  - → `insertTeam(compId, name, organization, metadata)`
  - → return created team
- `getTeam(teamId)` → `findTeamById(teamId)`
- `getTeamsByCompetition(compId, filters)`
  - → `findTeamsByCompetition(compId, filters)` — supports pagination
  - → return paginated results
- `updateTeam(teamId, updates)`
  - → `validateUpdates(updates)` — ensure only allowed fields
  - → `modifyTeam(teamId, updates)`
  - → return updated team
- `deleteTeam(teamId)`
  - → `checkTeamEmpty(teamId)` — ensure no dependent data or cascade
  - → `removeTeam(teamId)`
  - → return deletion confirmation
- `addTeamMember(teamId, userId, role)`
  - → `validateRole(role)` — valid team roles
  - → `insertTeamMember(teamId, userId, role)`
  - → return member record
- `removeTeamMember(teamId, userId)` → `deleteTeamMember(teamId, userId)`
- `getTeamMembers(teamId)` → `findMembersByTeam(teamId)`
- `getTeamStatistics(teamId)`
  - → `countTeamMembers(teamId)`
  - → `countImagesByTeam(teamId)`
  - → `countModelsByTeam(teamId)`
  - → `getTeamRank(teamId)`
  - → return aggregated statistics

**Repository**

- `insertTeam(compId, name, organization, metadata)`
- `findTeamById(teamId)`
- `findTeamsByCompetition(compId, filters)` — supports pagination
- `modifyTeam(teamId, updates)`
- `removeTeam(teamId)`
- `insertTeamMember(teamId, userId, role)`
- `deleteTeamMember(teamId, userId)`
- `findMembersByTeam(teamId)`
- `countTeamMembers(teamId)`
- `countImagesByTeam(teamId)`
- `countModelsByTeam(teamId)`

### Dependencies

- `team`, `team_member` tables
- **Competition module** — teams belong to competitions
- **Image module** — teams upload images
- **Model Submission Service** — teams submit models
- **Validation module** — teams validate labels

### Data Model

**Team Entity**
```
{
  id: UUID,
  competition_id: UUID,
  name: string,
  organization: string,
  metadata: JSON,
  created_at: timestamp,
  updated_at: timestamp
}
```

**Team Member Entity**
```
{
  id: UUID,
  team_id: UUID,
  user_id: UUID,
  role: enum('member' | 'lead' | 'viewer'),
  joined_at: timestamp
}
```

**Team Statistics (Computed)**
```
{
  team_id: UUID,
  total_members: integer,
  images_uploaded: integer,
  models_submitted: integer,
  current_rank: integer,
  computed_at: timestamp
}
```
