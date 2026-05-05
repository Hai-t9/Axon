# Background Tasks & Message Queue

## Overview
The `workers/` folder contains Celery task definitions and background job execution logic. This enables async processing for long-running operations like model evaluation.

## Purpose

- ✅ Run evaluations asynchronously (don't block HTTP requests)
- ✅ Queue multiple evaluation jobs
- ✅ Distribute jobs across multiple workers
- ✅ Retry failed tasks automatically
- ✅ Store task status for progress tracking
- ✅ Handle timeouts gracefully

## Architecture

```
workers/
├── __init__.py
├── celery_app.py           # Celery configuration
├── evaluation_worker.py    # Model evaluation tasks
├── executor.py             # Task execution logic
└── validator_worker.py     # Data validation tasks
```

## Components

### **celery_app.py**
**Purpose:** Celery configuration and setup

**Responsibilities:**
- Connect to Redis broker
- Configure task settings (timeout, retries)
- Register all task definitions
- Setup result backend

**Example:**
```python
from celery import Celery

app = Celery('axon')
app.conf.broker_url = 'redis://localhost:6379/0'
app.conf.result_backend = 'redis://localhost:6379/0'
app.conf.task_time_limit = 3600  # 1 hour
app.conf.task_soft_time_limit = 3500  # 58 minutes warning
```

---

### **evaluation_worker.py**
**Purpose:** Define evaluation tasks

**Responsibilities:**
- Load trained models from MinIO
- Run inference on test dataset
- Calculate metrics (accuracy, F1, etc.)
- Store results back to database
- Handle errors and retries

**Example:**
```python
from celery_app import app

@app.task(bind=True, max_retries=3)
def evaluate_model(self, submission_id: int):
    try:
        # Get model from MinIO
        model = model_store.download_model(submission_id)
        
        # Get test dataset
        test_data = get_test_dataset(submission_id)
        
        # Run evaluation
        results = executor.evaluate(model, test_data)
        
        # Store results
        save_evaluation_results(submission_id, results)
        
        return {"status": "success", "submission_id": submission_id}
    
    except Exception as exc:
        # Retry with exponential backoff
        raise self.retry(exc=exc, countdown=60)
```

---

### **executor.py**
**Purpose:** Low-level task execution logic

**Responsibilities:**
- Load models (PyTorch, TensorFlow, sklearn)
- Run inference on datasets
- Calculate metrics
- Handle GPU usage (if available)
- Generate evaluation reports

**Example:**
```python
class ModelExecutor:
    def evaluate(self, model, test_data):
        predictions = model.predict(test_data)
        metrics = {
            "accuracy": calculate_accuracy(predictions, test_data.labels),
            "f1": calculate_f1(predictions, test_data.labels),
            "precision": calculate_precision(predictions, test_data.labels),
        }
        return metrics
```

---

### **validator_worker.py**
**Purpose:** Define data validation tasks

**Responsibilities:**
- Validate dataset quality
- Check for duplicate images
- Verify label consistency
- Generate validation reports

**Example:**
```python
@app.task
def validate_dataset(self, dataset_id: int):
    dataset = get_dataset(dataset_id)
    
    # Run validations
    issues = []
    issues += check_duplicates(dataset)
    issues += check_labels(dataset)
    issues += check_formats(dataset)
    
    # Store validation report
    save_validation_report(dataset_id, issues)
```

---

## How Workers Are Used

### **From Evaluation Service**
```python
# services/evaluation/service.py
from workers.evaluation_worker import evaluate_model

class EvaluationService:
    def queue_evaluation(self, submission_id: int):
        # Queue task, don't wait for result
        task = evaluate_model.delay(submission_id)
        
        # Save task_id to database for tracking
        save_task_id(submission_id, task.id)
        
        return {"status": "queued", "task_id": task.id}
    
    def get_evaluation_status(self, task_id: str):
        # Check if task is still running
        task = evaluate_model.AsyncResult(task_id)
        return {
            "status": task.status,
            "result": task.result if task.ready() else None
        }
```

### **From Controller**
```python
# services/evaluation/controller.py
@router.post("/evaluate/{submission_id}")
async def start_evaluation(submission_id: int):
    # This returns immediately, doesn't wait
    result = evaluation_service.queue_evaluation(submission_id)
    return result

@router.get("/evaluation/{task_id}/status")
async def check_status(task_id: str):
    # Client polls to check progress
    return evaluation_service.get_evaluation_status(task_id)
```

---

## Task Flow

```
POST /evaluate/42
    ↓
Controller calls service.queue_evaluation(42)
    ↓
Service calls evaluate_model.delay(42)
    ↓
Task added to Redis queue
    ↓
Response: {"status": "queued", "task_id": "abc123"}
    ↓
(Immediately returns to client)
    ↓
Worker picks up task from queue
    ↓
Worker executes evaluate_model(42)
    ↓
Model loads, evaluates, stores results
    ↓
Client can poll GET /evaluation/abc123/status
    ↓
When done: {"status": "success", "result": {...}}
```

## Running Workers

### **Start Celery Worker**
```bash
celery -A workers.celery_app worker --loglevel=info
```

### **Monitor Tasks**
```bash
celery -A workers.celery_app events
```

### **Inspect Queue**
```python
from workers.celery_app import app
app.control.inspect().active()  # Currently running
app.control.inspect().reserved()  # Queued
```

## Task States

- **PENDING** - Task not yet picked up by worker
- **STARTED** - Worker started processing
- **SUCCESS** - Task completed successfully
- **FAILURE** - Task failed
- **RETRY** - Task is retrying after failure
- **REVOKED** - Task was cancelled

## Error Handling & Retries

```python
@app.task(
    bind=True,
    max_retries=3,
    default_retry_delay=60  # Wait 1 minute before retry
)
def evaluate_model(self, submission_id: int):
    try:
        # Do work
        evaluate(submission_id)
    except Exception as exc:
        # Exponential backoff: 60s, 120s, 240s
        raise self.retry(
            exc=exc,
            countdown=60 * (2 ** self.request.retries)
        )
```

## Task Monitoring

Store task status in database:

```python
# Database table: tasks
{
    id: "abc123",
    submission_id: 42,
    status: "running",
    started_at: "2024-01-15 10:00:00",
    completed_at: None,
    result: None
}
```

Update when task completes.

## Performance Considerations

- ✅ Short timeout - Prevent stuck tasks (3600s = 1 hour max)
- ✅ Result retention - Delete old results to save Redis memory
- ✅ Worker count - Scale workers based on evaluation demand
- ✅ Queue priority - High-priority tasks processed first
- ✅ Rate limiting - Max concurrent evaluations

## Configuration

```env
# Redis connection
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/0

# Task settings
CELERY_TASK_TIME_LIMIT=3600  # 1 hour
CELERY_TASK_SOFT_TIME_LIMIT=3500
CELERY_BROKER_CONNECTION_RETRY_ON_STARTUP=True
```

## Adding New Worker Tasks

1. Create new task in `evaluation_worker.py` or `validator_worker.py`
2. Use `@app.task` decorator
3. Import and call with `.delay()` from service
4. Poll status from controller
5. Store results in database

## Common Patterns

### **Long-running operation**
```python
@app.task
def long_operation(data_id):
    # Process large dataset
    for item in get_data(data_id):
        process(item)
    return {"status": "complete"}
```

### **Scheduled task** (runs periodically)
```python
from celery.schedules import crontab

app.conf.beat_schedule = {
    'cleanup-old-results': {
        'task': 'workers.tasks.cleanup_old_results',
        'schedule': crontab(hour=2, minute=0),  # 2 AM daily
    },
}
```

Workers = Async Task Processing 🔄
