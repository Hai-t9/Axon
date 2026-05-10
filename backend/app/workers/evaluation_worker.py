import json
import logging
import os
import shutil
import tempfile
from datetime import datetime
from uuid import UUID

from app.core.database import SessionLocal
from app.models import EvaluationJob, EvaluationTask, Model
from app.models.model_enums import EvaluationStatus, TaskStatus
from app.services.evaluation_orchestration.repository import (
    EvaluationOrchestrationRepository,
)
from app.storage.minio_client import storage_service

from .celery_app import celery_app
from .executor import compute_metrics, prepare_fold_data, run_docker_evaluation

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3, default_retry_delay=60)
def run_evaluation_task(self, task_id: str):
    logger.debug("Starting evaluation task %s (retry=%d)", task_id, self.request.retries)
    db = SessionLocal()
    try:
        repo = EvaluationOrchestrationRepository(db)
        task_uuid = UUID(task_id)

        task = db.query(EvaluationTask).filter(EvaluationTask.id == task_uuid).first()
        if not task:
            raise ValueError(f"EvaluationTask {task_id} not found")

        task.status = TaskStatus.executing.value  # type: ignore[assignment]
        task.started_at = datetime.utcnow()  # type: ignore[assignment]
        db.flush()

        job = db.query(EvaluationJob).filter(EvaluationJob.id == task.evaluation_id).first()
        if not job:
            raise ValueError(f"EvaluationJob {task.evaluation_id} not found")

        model = db.query(Model).filter(Model.id == job.model_id).first()
        if not model:
            raise ValueError(f"Model {job.model_id} not found")
        logger.debug("Task %s: job=%s model=%s protocol=%s fold=%d",
                     task_id, job.id, model.id, job.protocol, task.task_number)

        teams = repo.find_teams_by_competition(UUID(str(job.competition_id)))
        images_by_team = {}
        for team in teams:
            team_id = UUID(str(team.id))
            images = repo.find_images_by_team(team_id)
            images_by_team[team_id] = images

        images_dir, gt_path = prepare_fold_data(job, task, images_by_team, teams)
        temp_root = os.path.dirname(images_dir)

        model_dir = None
        try:
            model_dir = tempfile.mkdtemp(prefix="axon_model_")
            model_zip_path = os.path.join(model_dir, "model.zip")
            storage_path = str(model.storage_path)  # type: ignore[arg-type]
            model_bytes = storage_service.get_file(storage_path)
            logger.info("Fetched model zip from %s: %d bytes (empty=%s)", storage_path, len(model_bytes), len(model_bytes) == 0)
            with open(model_zip_path, "wb") as f:
                f.write(model_bytes)

            timeout = int(os.getenv("EVAL_DOCKER_TIMEOUT", "600"))
            memory_limit = os.getenv("EVAL_DOCKER_MEMORY_LIMIT", "4g")
            cpu_limit = os.getenv("EVAL_DOCKER_CPU_LIMIT", "2")
            gpu_enabled = os.getenv("EVAL_GPU_ENABLE", "false").lower() == "true"
            gpu_device = os.getenv("CUDA_VISIBLE_DEVICES") if gpu_enabled else None

            predictions = run_docker_evaluation(
                model_zip_path=model_zip_path,
                data_dir=images_dir,
                task_id=task_id,
                timeout=timeout,
                memory_limit=memory_limit,
                cpu_limit=cpu_limit,
                gpus=gpu_device,
            )

            with open(gt_path, "r") as f:
                ground_truth = json.load(f)

            metrics = compute_metrics(ground_truth, predictions)

            repo.record_evaluation_result(
                evaluation_id=UUID(str(job.id)),
                task_id=task_uuid,
                fold_number=int(str(task.task_number)),
                metrics=metrics,
            )

            task.status = TaskStatus.completed.value  # type: ignore[assignment]
            task.completed_at = datetime.utcnow()  # type: ignore[assignment]
            db.flush()

            _check_job_completion(UUID(str(job.id)), repo, db)

        finally:
            shutil.rmtree(temp_root, ignore_errors=True)
            if model_dir:
                shutil.rmtree(model_dir, ignore_errors=True)

    except Exception as exc:
        logger.exception(f"Evaluation task {task_id} failed")
        try:
            task_uuid = UUID(task_id)
            task = db.query(EvaluationTask).filter(EvaluationTask.id == task_uuid).first()
            if task:
                task.status = TaskStatus.failed.value  # type: ignore[assignment]
                task.error_message = str(exc)  # type: ignore[assignment]
                db.flush()

                repo = EvaluationOrchestrationRepository(db)
                _check_job_completion(UUID(str(task.evaluation_id)), repo, db)
        except Exception:
            logger.exception("Failed to update task failure status")
        finally:
            db.close()

        raise self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))

    else:
        db.commit()
        db.close()


def _check_job_completion(
    evaluation_id: UUID,
    repo: EvaluationOrchestrationRepository,
    db,
):
    completed_folds = repo.increment_completed_folds(evaluation_id)
    job = repo.find_evaluation_by_id(evaluation_id)
    if not job:
        return

    if completed_folds >= getattr(job, 'total_folds', 0):
        results = repo.find_completed_results(evaluation_id)
        if results:
            accuracies = [getattr(r, 'accuracy') for r in results]
            mean_accuracy = sum(accuracies) / len(accuracies)
            repo.write_final_score(UUID(str(job.model_id)), mean_accuracy)

        repo.update_evaluation_status(evaluation_id, EvaluationStatus.completed)
        repo.update_evaluation_timestamps(
            evaluation_id, completed_at=datetime.utcnow()
        )

        model = db.query(Model).filter(Model.id == UUID(str(job.model_id))).first()
        if model:
            from app.models.model_model import ModelStatus
            model.status = ModelStatus.COMPLETED.value  # type: ignore[assignment]

    elif _any_task_failed(evaluation_id, repo):
        repo.update_evaluation_status(evaluation_id, EvaluationStatus.failed)


def _any_task_failed(evaluation_id: UUID, repo: EvaluationOrchestrationRepository) -> bool:
    failed = repo.find_failed_tasks(evaluation_id)
    return len(failed) > 0
