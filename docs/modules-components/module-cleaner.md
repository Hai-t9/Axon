---
sidebar_position: 7
---

# Cleaner

## Overview

The **Cleaner Service** is a basic API service intended to maintain dataset integrity. Currently provides skeleton/mock implementations for most operations. Cleaing pipelines are queued as background tasks.

---

### Responsibility

Provides endpoints for running cleaning pipelines, scanning duplicates, cleaning team datasets, and optimizing storage. Most operations return mock/skeleton responses — full implementation is pending.

### Inputs / Outputs

**Controllers**
- `handleRunCleaningPipeline()`
- `handleScanDuplicates()`
- `handleCleanDataset(teamId)`
- `handleOptimizeStorage()`

**Services**
- `runCleaningPipeline(compId)` — queued as background task (implementation pending)
- `scanForDuplicates(compId)` — returns empty results (mock)
- `cleanDataset(teamId)` — returns hardcoded mock response
- `optimizeStorage()` — returns zero stats

**Repository**
- Standard DB query methods for image operations

### APIs

#### `POST /api/v1/competitions/{comp_id}/cleaner/run`
**Description:** Queue the full cleaning pipeline as a background task  
**Auth:** none currently enforced

| Field | Type | Required | Description |
|---|---|---|---|
| `:compId` | integer path | yes | Competition ID |

**Output:** `job_id`, `status`, `message`

---

#### `POST /api/v1/competitions/{comp_id}/cleaner/scan-duplicates`
**Description:** Scan for duplicate images (returns empty mock data)  
**Auth:** none currently enforced

| Field | Type | Required | Description |
|---|---|---|---|
| `:compId` | integer path | yes | Competition ID |

**Output:** `duplicate_groups` (empty array), `total_duplicates`

---

#### `POST /api/v1/teams/{team_id}/cleaner/clean`
**Description:** Run cleaning for a specific team's dataset (mock)  
**Auth:** none currently enforced

| Field | Type | Required | Description |
|---|---|---|---|
| `:teamId` | integer path | yes | Team ID |

**Output:** `images_processed` (10), `issues_found` (["Missing Labels"])

---

#### `POST /api/v1/competitions/{comp_id}/cleaner/optimize-storage`
**Description:** Optimize storage for a competition  
**Auth:** none currently enforced

| Field | Type | Required | Description |
|---|---|---|---|
| `:compId` | integer path | yes | Competition ID |

**Output:** `freed_mb`, `files_removed`, `completed_at`

### Notes

- **Auth**: None of the cleaner endpoints currently enforce authentication or role checks (docs state host/staff only — pending implementation)
- **Comp ID type**: Uses integer for `comp_id` (inconsistent with UUID used throughout the rest of the codebase)
- **Implementation**: Most endpoints return mock/skeleton data
- No `cleaning_job` or `duplicate_group` tables exist in the database

### Dependencies

- `image` table
- **Storage service** — for file-level operations
