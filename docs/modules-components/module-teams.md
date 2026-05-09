---
sidebar_position: 3
---

# Teams

## Overview

Manages competition participants and team administration. Handles team registration, member management, and participation tracking. Members are stored as a JSON dict of email-to-status on the Team record — no separate members table.

---

### Responsibility

Handles full CRUD operations on teams. Manages team profiles, member assignments (via `user_emails` JSON column — `{"email": 0|1}` where 0=invited/left, 1=joined), and participation history. Restricted to host/staff for team creation and deletion.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `createTeam` | `compId`, `name` | `{ id, comp_id, name, user_emails }` |
| `bulkCreateTeams` | `compId`, `{ team_name: [email1, ...] }` | `{ created, teams[] }` |
| `getTeam` | `teamId` | `{ id, comp_id, name, user_emails }` |
| `getTeamsByCompetition` | `compId`, `page`, `limit` | `{ teams[ ], total }` |
| `updateTeam` | `teamId`, `updates` | `{ id, ...updates }` |
| `deleteTeam` | `teamId` | `{ deleted: true, id }` |
| `addMemberByEmail` | `teamId`, `email` | `{ id, comp_id, name, user_emails }` |
| `removeMemberByEmail` | `teamId`, `email` | `{ removed: true }` |
| `getMembers` | `teamId` | `{ members[ { id, fullname, email } ] }` |
| `getTeamStatistics` | `teamId` | `{ total_members, images_uploaded, models_submitted }` |

### APIs

**Endpoints**

- `POST   /api/v1/competitions/{comp_id}/teams` — Create a new team — host/staff only
- `POST   /api/v1/competitions/{comp_id}/teams/bulk` — Bulk-create teams from `{team_name: [email, ...]}` — host/staff only
- `GET    /api/v1/competitions/{comp_id}/teams` — List all teams in competition — supports pagination
- `GET    /api/v1/teams/{team_id}` — Retrieve team details by ID
- `PUT    /api/v1/teams/{team_id}` — Update team metadata — host/staff only
- `DELETE /api/v1/teams/{team_id}` — Delete a team — host only
- `GET    /api/v1/teams/{team_id}/members` — List team members (resolved from `user_emails`)
- `POST   /api/v1/teams/{team_id}/members` — Add member by email — host/staff only
- `POST   /api/v1/teams/{team_id}/members/by-email` — Add member by email (alias) — host/staff only
- `DELETE /api/v1/teams/{team_id}/members/{email}` — Remove member by email — host/staff only
- `GET    /api/v1/teams/{team_id}/statistics` — Get team performance statistics

**Controller**

- `handleCreateTeam()`
- `handleBulkCreateTeams()`
- `handleGetTeam(teamId)`
- `handleGetTeamsByCompetition(compId)`
- `handleUpdateTeam(teamId)`
- `handleDeleteTeam(teamId)`
- `handleAddTeamMember(teamId, email)`
- `handleRemoveTeamMember(teamId, email)`
- `handleGetTeamMembers(teamId)`
- `handleGetTeamStatistics(teamId)`

**Service**

- `createTeam(compId, name)` → creates team with optional initial members via payload
- `bulkCreateTeams(compId, teamsData)` → iterate `{team_name: [emails]}`, create each
- `getTeam(teamId)` → `findTeamById(teamId)`
- `listTeams(compId, page, limit)` → paginated results
- `updateTeam(teamId, updates)` → validate + update
- `deleteTeam(teamId)` → verify + delete cascade
- `addMemberByEmail(teamId, email)` → verify user exists, set status to 1 in `user_emails`
- `removeMemberByEmail(teamId, email)` → set status to 0 or remove from `user_emails`
- `getMembers(teamId)` → resolve emails from `user_emails` to User records
- `getStatistics(teamId)` → count members, images, models

**Repository**

- `getById(teamId)` → Team | None
- `getByName(compId, name)` → Team | None
- `listByCompetition(compId, offset, limit)` → Team[]
- `countByCompetition(compId)` → int
- `create(teamData)` → Team
- `update(team, updates)` → Team
- `delete(team)` → None
- `getUserByEmail(email)` → User | None
- `setTeamMembers(team, userEmails)` → Team (writes `user_emails` JSON)
- `getTeamMembers(team)` → User[] (resolves emails from `user_emails`)
- `countImagesByTeam(teamId)` → int
- `countModelsByTeam(teamId)` → int

### Dependencies

- `team` table only (no separate members table — membership stored in `user_emails` JSON column with `{"email": 0|1}`)
- `user` table — for resolving member emails to user records
- **Competition module** — teams belong to competitions
- **Image module** — teams upload images
- **Model Submission Service** — teams submit models

### Data Model

**Team Entity**
```
{
  id: UUID (PK),
  comp_id: UUID (FK → competition.id),
  name: string (unique per competition),
  user_emails: object (JSON — {"user@email.com": 1, "other@email.com": 0})
}
```

**Membership status:** `1` = joined/active, `0` = invited but not joined, or previously removed.

**Team Statistics (Computed)**
```
{
  total_members: integer,
  images_uploaded: integer,
  models_submitted: integer
}
```
