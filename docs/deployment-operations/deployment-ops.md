---
sidebar_position: 1
---

# Deployment & Operations

## Current Status

Docker Compose and CI/CD pipelines are **not yet implemented**. The backend currently runs directly via `uvicorn` and the frontend via `flutter run`.

## Running in Production

### Backend

```bash
cd backend
pip install -r requirements.txt
# Configure .env with production Supabase credentials
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Celery Workers (for model evaluation)

```bash
# CPU mode (default)
cd backend
celery -A app.workers.celery_app worker --loglevel=info

# GPU mode (one worker per GPU)
EVAL_GPU_ENABLE=true EVAL_GPU_COUNT=2 bash app/workers/start_workers.sh
```

## Planned Infrastructure

- **Docker Compose** for orchestrating FastAPI + PostgreSQL + Redis + MinIO
- **Nginx** reverse proxy for API gateway
- **GitHub Actions** for automated deployment

## Monitoring & Logging

Logging is configured via the `GATEWAY_LOG_LEVEL` env var (default: INFO). Request logging middleware captures method, path, status code, duration, and request ID for every request.

## Error Handling

Domain errors use custom exception classes in `app/core/exceptions.py`:

| Exception | HTTP Status | Description |
|-----------|-------------|-------------|
| `AuthenticationError` | 401 | Invalid or expired token |
| `AuthorizationError` | 403 | Insufficient permissions |
| `NotFoundError` | 404 | Resource not found |
| `ValidationError` | 400 | Invalid input data |
