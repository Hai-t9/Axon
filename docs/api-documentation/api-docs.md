---
sidebar_position: 1
---

# API Documentation

All API endpoints are served under the `/api/v1` prefix.

## Authentication

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/register/signup` | No | Register a new user |
| POST | `/api/v1/register/login` | No | Login with credentials |
| GET | `/api/v1/register/me` | Yes | Get current user profile |

## Competition

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| POST | `/api/v1/competitions` | Yes | Host | Create competition |
| GET | `/api/v1/competitions` | Yes | Any | List competitions (paginated) |
| GET | `/api/v1/competitions/mine` | Yes | Any | List my competitions |
| POST | `/api/v1/competitions/join` | Yes | Any | Join via invitation link |
| POST | `/api/v1/competitions/{id}/leave` | Yes | Any | Leave competition |
| GET | `/api/v1/competitions/{id}` | Yes | Any | Get competition by ID |
| GET | `/api/v1/competitions/{id}/my-team` | Yes | Any | Get my team in competition |
| PUT | `/api/v1/competitions/{id}` | Yes | Host | Update competition |
| DELETE | `/api/v1/competitions/{id}` | Yes | Host | Delete competition |
| GET | `/api/v1/competitions/{id}/config` | Yes | Any | Get competition config |
| PUT | `/api/v1/competitions/{id}/config` | Yes | Host | Update competition config |

## Phase

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| GET | `/api/v1/competitions/{id}/phase` | Yes | Any | Get current phase |
| POST | `/api/v1/competitions/{id}/phase/advance` | Yes | Host | Advance to next phase |
| POST | `/api/v1/competitions/{id}/phase/decrement` | Yes | Host | Go back one phase |
| PUT | `/api/v1/competitions/{id}/phase/override` | Yes | Host | Override to any phase |
| PUT | `/api/v1/competitions/{id}/phase/deadline` | Yes | Host | Adjust deadline |
| PUT | `/api/v1/competitions/{id}/phase/transition-mode` | Yes | Host | Set auto/manual mode |
| GET | `/api/v1/competitions/{id}/phase/timeline` | Yes | Any | Get phase timeline |
| GET | `/api/v1/competitions/{id}/phase/history` | Yes | Any | Get audit log |
| POST | `/api/v1/competitions/{id}/phase/validate` | Yes | Any | Validate transition |

## Teams

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| POST | `/api/v1/competitions/{comp_id}/teams` | Yes | Host/Staff | Create team |
| POST | `/api/v1/competitions/{comp_id}/teams/bulk` | Yes | Host/Staff | Bulk create teams |
| GET | `/api/v1/competitions/{comp_id}/teams` | Yes | Any | List teams (paginated) |
| GET | `/api/v1/teams/{id}` | Yes | Any | Get team by ID |
| PUT | `/api/v1/teams/{id}` | Yes | Host/Staff | Update team |
| DELETE | `/api/v1/teams/{id}` | Yes | Host | Delete team |
| GET | `/api/v1/teams/{id}/members` | Yes | Any | List team members |
| POST | `/api/v1/teams/{id}/members` | Yes | Host/Staff | Add member by email |
| POST | `/api/v1/teams/{id}/members/by-email` | Yes | Host/Staff | Add member by email |
| DELETE | `/api/v1/teams/{id}/members/{email}` | Yes | Host/Staff | Remove member by email |
| GET | `/api/v1/teams/{id}/statistics` | Yes | Any | Get team statistics |

## Images

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/teams/{team_id}/images` | Yes | Upload image (multipart) |
| GET | `/api/v1/images/{id}` | Yes | Get image by ID |
| GET | `/api/v1/teams/{team_id}/images` | Yes | List team images (paginated, filterable) |
| GET | `/api/v1/competitions/{comp_id}/images` | Yes | List competition images |
| GET | `/api/v1/competitions/{comp_id}/images/stats` | Yes | Image statistics |
| PATCH | `/api/v1/images/{id}/status` | Yes | Update image status |
| DELETE | `/api/v1/images/{id}` | Yes | Delete image |

## Labels

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/images/{image_id}/labels` | Yes | Create label |
| GET | `/api/v1/images/{image_id}/labels` | Yes | Get label |
| PUT | `/api/v1/images/{image_id}/labels` | Yes | Update label |
| POST | `/api/v1/images/{image_id}/labels/validate` | Yes | Validate label (Staff/Host) |

## Validation

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| POST | `/api/v1/competitions/{comp_id}/validations/generate` | Yes | Host | Generate validation assignments |
| GET | `/api/v1/competitions/{comp_id}/validations/list` | Yes | Any | Get validation queue |
| POST | `/api/v1/images/{image_id}/validations` | Yes | Any | Submit vote |
| POST | `/api/v1/images/{image_id}/validations/skip` | Yes | Any | Skip image |
| GET | `/api/v1/competitions/{comp_id}/validations/pending` | Yes | Any | Pending validations |

## Cleaner

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/competitions/{comp_id}/cleaner/run` | Queue cleaning pipeline |
| POST | `/api/v1/competitions/{comp_id}/cleaner/scan-duplicates` | Scan duplicates (mock) |
| POST | `/api/v1/teams/{team_id}/cleaner/clean` | Clean dataset (mock) |
| POST | `/api/v1/competitions/{comp_id}/cleaner/optimize-storage` | Optimize storage |

## Model Submission

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| POST | `/api/v1/competitions/{comp_id}/models/submit` | Yes | Participant | Submit model (.zip) |
| GET | `/api/v1/competitions/{comp_id}/models/spec` | Yes | Any | Get submission spec |
| GET | `/api/v1/competitions/{comp_id}/models` | Yes | Any | List models (paginated) |
| GET | `/api/v1/teams/{team_id}/models` | Yes | Any | List team models |
| GET | `/api/v1/teams/{team_id}/models/history` | Yes | Any | Get submission history |
| GET | `/api/v1/models/{model_id}` | Yes | Any | Get model details |
| PUT | `/api/v1/models/{model_id}/schedule` | Yes | Any | Schedule for evaluation |
| DELETE | `/api/v1/models/{model_id}` | Yes | Any | Delete model |

## Evaluation

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| POST | `/api/v1/competitions/{comp_id}/models/{model_id}/evaluate` | Yes | Host/Staff | Schedule evaluation |
| GET | `/api/v1/competitions/{comp_id}/models/{model_id}/evaluate/status` | Yes | Any | Get evaluation status |
| GET | `/api/v1/evaluations/{id}` | Yes | Any | Get evaluation status |
| GET | `/api/v1/evaluations/{id}/results` | Yes | Any | Get evaluation results |
| PUT | `/api/v1/evaluations/{id}/retry` | Yes | Host/Staff | Retry failed evaluation |
| GET | `/api/v1/competitions/{comp_id}/evaluations` | Yes | Any | List evaluations |
| GET | `/api/v1/competitions/{comp_id}/results` | Yes | Any | Get competition results |

## Dashboard

| Method | Path | Auth | Role | Description |
|--------|------|------|------|-------------|
| GET | `/api/v1/competitions/{comp_id}/dashboard` | Yes | Any | Get dashboard |
| GET | `/api/v1/competitions/{comp_id}/dashboard/role` | Yes | Any | Get user role |
| GET | `/api/v1/competitions/{comp_id}/dashboard/cache` | Yes | Host/Staff | Get cached dashboard |
| DELETE | `/api/v1/competitions/{comp_id}/dashboard/cache` | Yes | Host | Clear cache |

## Leaderboard

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/competitions/{comp_id}/leaderboard` | Yes | Get rankings |

## Health

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check (DB status, uptime) |

## Request / Response Formats

All endpoints accept and return JSON (except file uploads which use `multipart/form-data`).

Authentication uses `Authorization: Bearer <token>` header.

Pagination uses `page` and `limit` query parameters (default: page=1, limit=20, max limit=100).
