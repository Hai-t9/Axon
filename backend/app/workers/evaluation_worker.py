"""
FILE: backend/app/workers/evaluation_worker.py

Celery task that performs model evaluation asynchronously.

The task receives pre-built train/test splits (filepaths + labels) from
EvaluationService, loads the Docker image archive from storage, runs the
model against the test split, and calls back the internal API endpoint to
persist the score.

For now the "model execution" step is a stub that implements the same
majority-class baseline as EvaluationService._run_inline().  Replace
``_execute_model`` with a real Docker SDK call when the evaluation
container interface is finalised.
"""

from __future__ import annotations

import logging
import os
import time
from collections import defaultdict

import requests

from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)

# Internal API base URL (same host — worker runs alongside the API).
API_BASE = os.getenv("API_BASE_URL", "http://localhost:8000/api/v1")
WORKER_SECRET = os.getenv("WORKER_SECRET", "dev-worker-secret")


@celery_app.task(
    bind=True,
    max_retries=3,
    default_retry_delay=60,
    name="evaluation.run_evaluation_task",
)
def run_evaluation_task(
    self,
    model_id: int,
    train_filepaths: list[str],
    train_labels: list[str],
    test_filepaths: list[str],
    test_labels: list[str],
) -> dict:
    """
    Background task that evaluates a submitted model.

    Parameters
    ----------
    model_id:
        Primary key of the Model row to evaluate.
    train_filepaths / train_labels:
        Parallel lists for the training split.
    test_filepaths / test_labels:
        Parallel lists for the test split.

    Returns
    -------
    dict with model_id and final score.
    """
    logger.info(
        "Starting evaluation for model %d | train=%d test=%d",
        model_id,
        len(train_filepaths),
        len(test_filepaths),
    )
    start = time.time()

    try:
        score = _execute_model(
            model_id=model_id,
            train_filepaths=train_filepaths,
            train_labels=train_labels,
            test_filepaths=test_filepaths,
            test_labels=test_labels,
        )

        # Persist result via internal API.
        _store_result(model_id, score)

        elapsed = time.time() - start
        logger.info(
            "Evaluation complete for model %d | score=%.4f | elapsed=%.1fs",
            model_id,
            score,
            elapsed,
        )
        return {"model_id": model_id, "score": score, "elapsed_seconds": elapsed}

    except Exception as exc:
        logger.error("Evaluation failed for model %d: %s", model_id, exc)
        raise self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _execute_model(
    model_id: int,
    train_filepaths: list[str],
    train_labels: list[str],
    test_filepaths: list[str],
    test_labels: list[str],
) -> float:
    """
    Run the model and return accuracy score in [0, 1].

    CURRENT IMPLEMENTATION: majority-class baseline.
    Replace with Docker SDK execution when the container interface
    is ready.  The Docker container should:
      1. Accept a JSON manifest of train/test filepaths + labels.
      2. Train (or load weights) and predict on the test split.
      3. Print a JSON result: {"accuracy": 0.87, "f1": 0.85}
    """
    # Build majority label from training set.
    label_counts: dict[str, int] = defaultdict(int)
    for label in train_labels:
        label_counts[label] += 1

    if not label_counts or not test_labels:
        return 0.0

    majority_label = max(label_counts, key=lambda k: label_counts[k])
    correct = sum(1 for label in test_labels if label == majority_label)
    return round(correct / len(test_labels), 4)


def _store_result(model_id: int, score: float) -> None:
    """
    POST the score to the internal result endpoint.
    Retries up to 3 times with exponential back-off.
    """
    url = f"{API_BASE}/evaluations/{model_id}/result"
    headers = {"X-Worker-Secret": WORKER_SECRET}

    for attempt in range(3):
        try:
            resp = requests.post(
                url, params={"score": score}, headers=headers, timeout=10
            )
            resp.raise_for_status()
            return
        except requests.RequestException as exc:
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)