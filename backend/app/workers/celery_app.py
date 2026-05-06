"""
FILE: backend/app/workers/celery_app.py

Celery application factory.

The broker and result backend both use Redis.  When Redis is unavailable
(e.g. in development without Docker) the import still succeeds; tasks
will fall back to inline execution inside EvaluationService.
"""

import os

from celery import Celery

BROKER_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
RESULT_BACKEND = os.getenv("REDIS_URL", "redis://localhost:6379/0")

celery_app = Celery(
    "axon",
    broker=BROKER_URL,
    backend=RESULT_BACKEND,
    include=["app.workers.evaluation_worker"],
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    task_time_limit=3600,          # 1 hour hard limit per task
    task_soft_time_limit=3500,     # Send SoftTimeLimitExceeded at 58 min
    worker_prefetch_multiplier=1,  # One task per worker at a time
    task_acks_late=True,           # Ack only after task completes (safe retry)
    broker_connection_retry_on_startup=True,
)