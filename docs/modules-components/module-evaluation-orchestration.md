---
sidebar_position: 11
---

# Evaluation Orchestration

## Overview

Coordinates model evaluation across multiple protocols (Standard K-Fold, LOTO, TOTO) by scheduling evaluation jobs, distributing tasks to worker queues, tracking evaluation progress, aggregating results, and handling failures with retry logic. Orchestrates the entire evaluation pipeline to ensure fair and consistent model assessment.

---

### Responsibility

Manages the evaluation lifecycle: protocol selection, job scheduling, task distribution to evaluation workers, progress tracking, result aggregation, and failure handling. Orchestrates cooperation between the Task Queue, Evaluation Workers, and results storage.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `scheduleEvaluation` | `modelId`, `protocol`, `folds` | `{ evaluation_id, model_id, protocol, status, scheduled_at }` |
| `getEvaluationStatus` | `evaluationId` | `{ id, model_id, protocol, progress, status, completed_folds }` |
| `getEvaluationResults` | `evaluationId` | `{ evaluation_id, model_id, results[ { fold, accuracy, metrics } ] }` |
| `retryFailedEvaluation` | `evaluationId` | `{ evaluation_id, retry_count, restarted: boolean }` |
| `getCompetitionResults` | `compId` | `{ evaluations[ ], final_rankings }` |

### APIs

**Endpoints**

- `POST   /models/:modelId/evaluate` — Schedule model for evaluation — host/staff only
- `GET    /evaluations/:evaluationId` — Get evaluation status
- `GET    /evaluations/:evaluationId/results` — Get evaluation results
- `PUT    /evaluations/:evaluationId/retry` — Retry failed evaluation — host/staff only
- `GET    /competitions/:compId/evaluations` — Get all evaluations for competition
- `GET    /competitions/:compId/results` — Get competition results with rankings

**Controller**

- `handleScheduleEvaluation(modelId, protocol, folds)`
- `handleGetEvaluationStatus(evaluationId)`
- `handleGetEvaluationResults(evaluationId)`
- `handleRetryFailedEvaluation(evaluationId)`
- `handleGetCompetitionEvaluations(compId)`
- `handleGetCompetitionResults(compId)`

**Service**

- `scheduleEvaluation(modelId, protocol, userId)`
  - → `validateModel(modelId)` — ensure model ready
  - → `determineEvaluationStrategy(protocol)`
  - → `generateEvaluationTasks(modelId, protocol)` — create fold tasks
  - → `createEvaluationJob(modelId, protocol, tasks)`
  - → `queueTasks(tasks)` → Task Queue
  - → return evaluation_id and tracking info
- `getEvaluationStatus(evaluationId)` → status + progress
- `getEvaluationResults(evaluationId)`
  - → `fetchCompletedResults(evaluationId)`
  - → `aggregateMetrics(results)` — average accuracy, std dev, etc.
  - → return aggregated results
- `retryFailedEvaluation(evaluationId, userId)`
  - → `validateRetryEligible(evaluationId)`
  - → `resubmitFailedTasks(evaluationId)`
  - → `incrementRetryCounter(evaluationId)`
  - → return restart confirmation
- `getCompetitionResults(compId)`
  - → `fetchAllEvaluations(compId)`
  - → `aggregateFinalScores(evaluations)`
  - → `generateLeaderboard(compId)` — call Leaderboard Service
  - → return final rankings

**Repository**

- `createEvaluationJob(modelId, protocol, tasks)`
- `findEvaluationById(evaluationId)`
- `findEvaluationsByCompetition(compId)`
- `updateEvaluationStatus(evaluationId, status)`
- `recordEvaluationResult(evaluationId, fold, metrics)`
- `findCompletedResults(evaluationId)`
- `incrementRetryCounter(evaluationId)`

### Dependencies

- `evaluation`, `evaluation_task`, `evaluation_result` tables
- **Task Queue / Message Broker** — queues evaluation jobs
- **Evaluation Workers** — executes evaluation tasks
- **Model Storage** — retrieves model files
- **Image Storage** — retrieves dataset folds
- **Leaderboard Service** — generates rankings from results
- **Primary Database** — stores results

### Data Model

**Evaluation Job**
```
{
  id: UUID,
  model_id: UUID,
  competition_id: UUID,
  protocol: enum('standard' | 'loto' | 'toto'),
  status: enum('scheduled' | 'queued' | 'in_progress' | 'completed' | 'failed'),
  total_folds: integer,
  completed_folds: integer,
  retry_count: integer (default: 0),
  max_retries: integer (default: 3),
  created_at: timestamp,
  started_at: timestamp (nullable),
  completed_at: timestamp (nullable)
}
```

**Evaluation Task**
```
{
  id: UUID,
  evaluation_id: UUID,
  task_number: integer (fold number),
  status: enum('pending' | 'queued' | 'executing' | 'completed' | 'failed'),
  worker_id: string (nullable, assigned worker),
  created_at: timestamp,
  started_at: timestamp (nullable),
  completed_at: timestamp (nullable),
  error_message: string (nullable)
}
```

**Evaluation Result**
```
{
  id: UUID,
  evaluation_id: UUID,
  task_id: UUID,
  fold_number: integer,
  accuracy: float,
  precision: float,
  recall: float,
  f1_score: float,
  confusion_matrix: JSON,
  execution_time_seconds: float,
  computed_at: timestamp
}
```

### Evaluation Protocols

**1. Standard K-Fold**
- Train on k-1 folds, test on fold k
- Repeat for each fold
- Average accuracy across folds

**2. LOTO (Leave-One-Team-Out)**
- Train on all teams except one
- Test on excluded team
- Measures generalization across team domains
- Repeat for each team

**3. TOTO (Train-On-One-Team-Only)**
- Train on single team's data
- Test on same team (or held-out portion)
- Assesses single team's data quality/consistency

### Workflow

```
1. Model submitted
2. Evaluation Orchestration scheduled
   └─ Determine protocol (Standard/LOTO/TOTO)
   └─ Generate evaluation tasks (one per fold)
3. Tasks queued to Task Queue
4. Evaluation Workers pick up tasks
5. Results aggregated as tasks complete
6. Final scores published to Leaderboard Service
7. Rankings updated in real-time
```
