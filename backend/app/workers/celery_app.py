import multiprocessing
import os

from celery import Celery

# Dedicated env var for Celery's task queue (separate from REDIS_URL which is for caching).
# Defaults to localhost so the worker works out of the box without env overrides.
CELERY_REDIS_URL = os.getenv("CELERY_REDIS_URL", "redis://localhost:6379/0")

celery_app = Celery(
    "axon",
    broker=CELERY_REDIS_URL,
    backend=CELERY_REDIS_URL,
    include=["app.workers.evaluation_worker"],
)

gpu_enabled = os.getenv("EVAL_GPU_ENABLE", "false").lower() == "true"
gpu_count = int(os.getenv("EVAL_GPU_COUNT", "1"))
concurrency = gpu_count if gpu_enabled else multiprocessing.cpu_count()

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    task_time_limit=3600,
    task_soft_time_limit=3500,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    worker_concurrency=concurrency,
    broker_connection_retry_on_startup=True,
)
