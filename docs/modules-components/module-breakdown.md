---
---

# Module Breakdown

## Overview

Axon's modular architecture is organized into specialized modules, each handling a specific domain within the competition platform. Below is a summary of all available modules with links to their detailed documentation.

## Available Modules

### 1. **Competition Module**
Manages the full lifecycle of competitions: creation, configuration, joining/leaving, and deletion. Restricted to host role for administrative operations.

**Key Operations:** Create, Read, Update, Delete competitions; manage configuration; join/leave via invitation links.

**Read:** [Competition Module Documentation](./module-competition.md)

---

### 2. **Phase Module**
Manages competition phase lifecycle through string digit phases ("0"-"5"). State transitions, deadlines, audit history are all stored in a single `phase_log` table with JSON. Supports auto-advance on deadline, manual advance/decrement, and override.

**Key Operations:** Get current phase, advance phase, decrement phase, override phase, adjust deadline, set transition mode, view timeline and history.

**Read:** [Phase Module Documentation](./module-phase.md)

---

### 3. **Teams Module**
Manages competition participants and team administration. Handles team registration, member management via email-based `user_emails` JSON, and bulk creation.

**Key Operations:** Create (single/bulk), read, update, delete teams; manage team members by email; retrieve team statistics.

**Read:** [Teams Module Documentation](./module-teams.md)

---

### 4. **Image Module**
Handles all image lifecycle operations: uploading, retrieving, filtering, status management, and deletion. Also performs format/size validation, deduplication via hashing, and EXIF metadata extraction at upload time.

**Key Operations:** Upload images, validate formats, retrieve by team/competition, update status, delete images, get image stats.

**Read:** [Image Module Documentation](./module-image.md)

---

### 5. **Label Module**
Manages image labels submitted by teams throughout the competition. Handles full CRUD on image labels and label validation status. Called by both external APIs and the Validation module for finalization.

**Key Operations:** Create, read, update labels; validate labels (staff/host only).

**Read:** [Label Module Documentation](./module-label.md)

---

### 6. **Validation Module**
Handles the participant voting workflow for finalizing image labels. Uses round-robin assignment to distribute images across teams, collects votes, and auto-finalizes labels via majority vote when threshold is reached.

**Key Operations:** Generate assignments, get validation list, submit votes, skip images, auto-finalize labels.

**Read:** [Validation Module Documentation](./module-validation.md)

---

### 7. **Data Ingestion (via Image Module)**
Image data collection and ingestion is handled directly by the Image module. There is no separate Data Ingestion service.

**Read:** [Data Ingestion Documentation](./module-data-ingestion.md)

---

### 8. **Data Validation (via Validation Module)**
Label validation workflow is handled by the Validation module. There is no separate Data Validation service.

**Read:** [Data Validation Documentation](./module-data-validation.md)

---

### 9. **Cleaner Module**
Maintains dataset integrity by providing endpoints for deduplication, corruption detection, format normalization, and storage optimization. Currently provides skeleton/mock implementations — full implementation is pending.

**Key Operations:** Run cleaning pipeline (queued), scan duplicates, clean dataset, optimize storage.

**Read:** [Cleaner Module Documentation](./module-cleaner.md)

---

### 10. **Model Submission Module**
Handles participant model submissions during evaluation phase. Participants submit a Docker build context (.zip). Validates format, structure, eligibility, and phase. Auto-schedules validated models for evaluation.

**Key Operations:** Submit model, validate Docker submission, get model history, schedule for evaluation, delete model.

**Read:** [Model Submission Module Documentation](./module-model-submission.md)

---

### 11. **Evaluation Orchestration Module**
Coordinates model evaluation across multiple protocols (Standard K-Fold, LOTO, TOTO). Schedules evaluation jobs, distributes tasks to Celery workers, tracks progress, aggregates results, handles retries.

**Key Operations:** Schedule evaluation, get status, retrieve results, retry failed evaluations, get competition results.

**Read:** [Evaluation Orchestration Module Documentation](./module-evaluation-orchestration.md)

---

### 12. **Dashboard Module**
Passive read module that aggregates competition state from multiple tables and returns a unified dashboard view. Supports Redis caching and role-based response formats (host/staff vs participant).

**Key Operations:** Get dashboard, get user role, retrieve cached dashboard, clear cache.

**Read:** [Dashboard Module Documentation](./module-dashboard.md)

---

### 13. **Leaderboard Module**
Standalone read module that computes and returns team rankings from scores stored in the database.

**Key Operations:** Get leaderboard with rankings (supports type and limit params).

**Read:** [Leaderboard Module Documentation](./module-leaderboard.md)

---

## Module Hierarchy & Data Flow

```
Competition (root)
    ├── Phase (phase management — single phase_log table with JSON)
    ├── Teams (team management — user_emails JSON, not user_ids)
    ├── Image (image uploads & management — handles ingestion)
    │   ├── Label (label management)
    │   │   └── Validation (voting workflow — round-robin assignment)
    │   └── Cleaner (data quality & deduplication — skeleton/mock)
    ├── Model Submission (Docker-based model uploads)
    │   └── Evaluation Orchestration (coordinate evaluations via Celery)
    ├── Dashboard (aggregation — read-only, role-based)
    └── Leaderboard (rankings — read-only)
```

## Module Structure Template

Each module documentation follows this standard structure:

### Responsibility
Clear description of what the module does and its core responsibilities.

### Inputs / Outputs
Table of main functions with their inputs and outputs.

### APIs
Detailed endpoint specifications with authentication requirements and parameters.

### Dependencies
List of related modules and database tables the module depends on.

### Data Model
Entity schemas and relationships (when applicable).
