---
---

# Module Breakdown

## Overview

Axon's modular architecture is organized into specialized modules, each handling a specific domain within the competition platform. Below is a summary of all available modules with links to their detailed documentation.

## Available Modules

### 1. **Competition Module**
Manages the full lifecycle of competitions: creation, configuration, and deletion. Restricted to host role for administrative operations.

**Key Operations:** Create, Read, Update, Delete competitions; manage configuration.

**Read:** [Competition Module Documentation](./module-competition.md)

---

### 2. **Phase Module**
Manages competition phase lifecycle, state transitions, deadlines, and phase history. Provides granular control over phase progression including automatic transitions, manual overrides, and deadline adjustments.

**Key Operations:** Get current phase, advance phase, override phase, adjust deadline, manage transition mode, view timeline and history.

**Read:** [Phase Module Documentation](./module-phase.md)

---

### 3. **Teams Module**
Manages competition participants and team administration. Handles team registration, member management, team metadata storage, and participation tracking across competition seasons.

**Key Operations:** Create, read, update, delete teams; manage team members; retrieve team statistics.

**Read:** [Teams Module Documentation](./module-teams.md)

---

### 4. **Data Ingestion Module**
Manages field image data collection and initial ingestion. Handles image uploads from mobile applications, validates metadata, stores images in distributed storage, and queues images for team validation.

**Key Operations:** Ingest images, validate formats, validate metadata, batch ingest, retrieve ingestion statistics.

**Read:** [Data Ingestion Module Documentation](./module-data-ingestion.md)

---

### 5. **Image Module**
Handles all lifecycle operations for competition images: uploading, retrieving, filtering, status management, and deletion.

**Key Operations:** Upload, retrieve, filter, update status, delete images.

**Read:** [Image Module Documentation](./module-image.md)

---

### 6. **Label Module**
Manages image labels submitted by teams throughout the competition. Handles full CRUD on image labels.

**Key Operations:** Create, read, update labels; validate labels.

**Read:** [Label Module Documentation](./module-label.md)

---

### 7. **Data Validation Module**
Coordinates data validation workflow where teams review and correct image labels. Manages validation queues, enforces deadlines, and tracks validation progress.

**Key Operations:** Get validation queue, submit label corrections, track progress, complete validation, enforce deadlines.

**Read:** [Data Validation Module Documentation](./module-data-validation.md)

---

### 8. **Cleaner Module**
Maintains dataset integrity by automating deduplication, corruption detection, format normalization, and metadata sanitization.

**Key Operations:** Run cleaning pipelines, detect duplicates, normalize formats, rebuild datasets.

**Read:** [Cleaner Module Documentation](./module-cleaner.md)

---

### 9. **Validation Module**
Handles the participant voting workflow for finalizing image labels. Each participant receives a queue of images to validate with majority voting for consensus.

**Key Operations:** Get validation queue, submit votes, finalize labels via majority voting.

**Read:** [Validation Module Documentation](./module-validation.md)

---

### 10. **Model Submission Module**
Handles participant model submissions during evaluation phase. Manages model file uploads, validates model format and structure, stores models with versioning, and schedules for evaluation.

**Key Operations:** Submit model, validate format, retrieve model history, schedule for evaluation.

**Read:** [Model Submission Module Documentation](./module-model-submission.md)

---

### 11. **Evaluation Orchestration Module**
Coordinates model evaluation across multiple protocols (Standard K-Fold, LOTO, TOTO). Schedules evaluation jobs, distributes tasks to workers, tracks progress, aggregates results.

**Key Operations:** Schedule evaluation, get status, retrieve results, retry failed evaluations, get competition results.

**Read:** [Evaluation Orchestration Module Documentation](./module-evaluation-orchestration.md)

---

### 12. **Dashboard Module**
Passive read module that aggregates competition state from multiple tables and returns a unified dashboard view. Supports Redis caching.

**Key Operations:** Get dashboard, retrieve cached dashboard, clear cache.

**Read:** [Dashboard Module Documentation](./module-dashboard.md)

---

### 13. **Leaderboard Module**
Standalone read module that computes and returns team rankings from scores stored in the database.

**Key Operations:** Get leaderboard with rankings.

**Read:** [Leaderboard Module Documentation](./module-leaderboard.md)

---

## Module Dependency Graph

```
API & Orchestration Layer:
├── Competition Service
├── Phase Service
├── Teams Service
├── Data Ingestion Service
├── Label Service
├── Cleaner Service
├── Data Validation Service
├── Model Submission Service
├── Evaluation Orchestration Service
└── Leaderboard Service

Module Hierarchy & Data Flow:
Competition (root)
    ├── Phase (phase management)
    ├── Teams (team management)
    ├── Data Ingestion (image uploads) → Image Module
    │   ├── Label (label management)
    │   │   ├── Data Validation (team validation workflow)
    │   │   │   └── Validation Module (voting workflow)
    │   │   └── Cleaner (data quality & deduplication)
    ├── Model Submission (model uploads)
    │   └── Evaluation Orchestration (coordinate evaluations)
    ├── Dashboard (aggregation - read-only)
    └── Leaderboard (rankings - read-only)
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
