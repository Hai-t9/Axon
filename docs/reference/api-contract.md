---
sidebar_position: 1
title: API Contract
---

# API Contract

## Base URL

`/api/v1`

## Conventions

- JSON request and response bodies
- Authorization header: `Authorization: Bearer <token>`
- Timestamps are ISO 8601 strings in UTC

## Dashboard module

| Method | Endpoint | Description |
| --- | --- | --- |
| GET | `/dashboard` | Team summary, active phase, and key metrics |
| GET | `/dashboard/phases` | Phase status and progress |
| GET | `/dashboard/image-stats` | Dataset and image statistics |
| GET | `/teams/{teamId}` | Team profile and membership |
| GET | `/config` | Active configuration and rules |
| POST | `/cache/dashboard/refresh` | Refresh dashboard cache |
| DELETE | `/cache/dashboard` | Clear dashboard cache |

## Leaderboard module

| Method | Endpoint | Description |
| --- | --- | --- |
| GET | `/leaderboard` | Current leaderboard for a phase |
| GET | `/leaderboard/aggregates` | Aggregated scores per team |
| POST | `/leaderboard/refresh` | Recompute rankings |
| DELETE | `/cache/leaderboard` | Clear leaderboard cache |

## Evaluation module

| Method | Endpoint | Description |
| --- | --- | --- |
| POST | `/evaluations/submissions` | Submit a model for evaluation |
| POST | `/evaluations/submissions/{submissionId}/run` | Trigger evaluation job |
| GET | `/evaluations/jobs/{jobId}` | Job status and runtime info |
| GET | `/evaluations/results/{submissionId}` | Score and metrics for a submission |

## Dataset and phase management

| Method | Endpoint | Description |
| --- | --- | --- |
| GET | `/datasets` | List datasets and versions |
| POST | `/datasets` | Create dataset metadata |
| POST | `/datasets/{datasetId}/versions` | Register a new dataset version |
| GET | `/phases` | List challenge phases |
| POST | `/phases` | Create a phase and rules |

## Admin utilities

| Method | Endpoint | Description |
| --- | --- | --- |
| GET | `/audit/logs` | Review audit events |
| POST | `/cache/clear` | Clear all module caches |
