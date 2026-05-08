---
sidebar_position: 11
---

# Evaluation Orchestration

## Overview

Coordinates model evaluation across multiple protocols (Standard K-Fold, LOTO, TOTO) by scheduling evaluation jobs, distributing tasks to worker queues, tracking evaluation progress, aggregating results, and handling failures with retry logic. Orchestrates the entire evaluation pipeline to ensure fair and consistent model assessment.

**Auto-triggered on submission**: The moment a participant submits a model, the evaluation pipeline fires automatically — no organizer intervention needed. The competition's `Config.evaluation` field determines the protocol (standard/loto/toto).

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

- `POST   /competitions/:compId/models/:modelId/evaluate` — (Re-)schedule evaluation manually — host/staff only
- `GET    /competitions/:compId/models/:modelId/evaluate/status` — Get evaluation status for a model
- `GET    /evaluations/:evaluationId` — Get evaluation status
- `GET    /evaluations/:evaluationId/results` — Get evaluation results
- `PUT    /evaluations/:evaluationId/retry` — Retry failed evaluation — host/staff only
- `GET    /competitions/:compId/evaluations` — Get all evaluations for competition
- `GET    /competitions/:compId/results` — Get competition results with rankings

**Auto-trigger**: The primary path is automated — `POST /competitions/:compId/models/submit` in the Model Submission module calls `scheduleEvaluation()` immediately after storing the model. The manual POST endpoint exists for re-evaluation or edge cases.

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

### Workers

Evaluation workers are Celery processes that consume tasks from the Redis queue. Each worker runs one Docker container per task.

**GPU pinning** (see `start_workers.sh`):
- If `EVAL_GPU_ENABLE=true`, one worker is started per GPU, each with `CUDA_VISIBLE_DEVICES=N`
- Each worker runs `--concurrency=1` so one evaluation container gets the full GPU
- The executor passes `--gpus all -e CUDA_VISIBLE_DEVICES=N` to `docker run`

**CPU fallback** (default):
- If `EVAL_GPU_ENABLE=false`, a single worker uses all CPU cores
- `worker_concurrency` = `multiprocessing.cpu_count()`

**Resource limits** (configurable via `.env`):

| Env Var | Default | Description |
|---|---|---|
| `EVAL_DOCKER_TIMEOUT` | 600 | Max seconds per evaluation task |
| `EVAL_DOCKER_MEMORY_LIMIT` | 4g | Docker `--memory` limit |
| `EVAL_DOCKER_CPU_LIMIT` | 2 | Docker `--cpus` limit |
| `EVAL_GPU_ENABLE` | false | Enable GPU workers |
| `EVAL_GPU_COUNT` | 1 | Number of GPUs available |

**Start workers**:
```bash
# Auto-detect GPUs or CPU cores
./app/workers/start_workers.sh

# Or manually: GPU mode
CUDA_VISIBLE_DEVICES=0 celery -A app.workers.celery_app worker --concurrency=1

# Or manually: CPU mode
celery -A app.workers.celery_app worker --loglevel=info
```

### Dependencies

- `evaluation`, `evaluation_task`, `evaluation_result` tables
- **Task Queue / Redis + Celery** — queues evaluation jobs
- **Evaluation Workers** — Celery workers with Docker (GPU or CPU)
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
1. Model submitted → Model Submission Service calls scheduleEvaluation()
2. Evaluation Orchestration Service triggered automatically
   └─ Read competition protocol from Config.evaluation (standard/loto/toto)
   └─ Determine fold count (k / team count)
   └─ Create EvaluationJob (DB) + N EvaluationTasks (one per fold)
   └─ Queue tasks to Redis/Celery
3. Celery distributes tasks round-robin to available workers
4. Worker picks up a task:
   └─ prepare_fold_data() → copies only test images to temp dir
   └─ run_docker_evaluation() → builds + runs Docker container
       ├─ Mounts test images to /data:ro
       ├─ Sets --memory, --cpus, --network=none
       ├─ If GPUs enabled: --gpus all -e CUDA_VISIBLE_DEVICES=X
       └─ Container writes predictions.json to /output
   └─ compute_metrics() → accuracy, precision, recall, F1
   └─ record_evaluation_result() → DB
5. Resources cleaned up (temp dirs, Docker image removed)
6. _check_job_completion():
   ├─ All folds complete → aggregate metrics → write_final_score()
   ├─ Leaderboard reads final score from Evaluation table
   └─ Any fold failed → mark evaluation as failed
7. Frontend polls GET /competitions/:compId/models/:modelId/evaluate/status
   for live progress updates
```
```
