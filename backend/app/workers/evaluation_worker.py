import json
import logging
import os
import shutil
import tempfile
from datetime import datetime
from typing import Optional
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
    logger.info("=== WORKER: TASK STARTED === task=%s retry=%d/%d", task_id, self.request.retries, 3)
    db = SessionLocal()
    try:
        repo = EvaluationOrchestrationRepository(db)
        task_uuid = UUID(task_id)

        task = db.query(EvaluationTask).filter(EvaluationTask.id == task_uuid).first()
        if not task:
            raise ValueError(f"EvaluationTask {task_id} not found")
        logger.info("WORKER: Task found: fold=%d status=%s eval_id=%s", task.task_number, task.status, task.evaluation_id)

        def _update_progress(msg: str, status: Optional[TaskStatus] = None):
            try:
                repo.update_task_progress(task_uuid, msg, status=status)
            except Exception:
                logger.warning("Failed to update task progress: %s", msg)

        task.status = TaskStatus.executing.value  # type: ignore[assignment]
        task.started_at = datetime.utcnow()  # type: ignore[assignment]
        _update_progress("Starting evaluation task", TaskStatus.executing)
        logger.info("WORKER: Task status set to EXECUTING")

        job = db.query(EvaluationJob).filter(EvaluationJob.id == task.evaluation_id).first()
        if not job:
            raise ValueError(f"EvaluationJob {task.evaluation_id} not found")
        logger.info("WORKER: Job found: id=%s protocol=%s total_folds=%d", job.id, job.protocol, job.total_folds)

        model = db.query(Model).filter(Model.id == job.model_id).first()
        if not model:
            raise ValueError(f"Model {job.model_id} not found")
        logger.info("WORKER: Model found: id=%s filename=%s team=%s", model.id, model.filename, model.team_id)

        teams = repo.find_teams_by_competition(UUID(str(job.competition_id)))
        logger.info("WORKER: Competition has %d teams", len(teams))
        for t in teams:
            logger.info("WORKER:   Team id=%s name=%s", t.id, t.name)
        images_by_team = {}
        for team in teams:
            team_id = UUID(str(team.id))
            images = repo.find_images_by_team(team_id)
            images_by_team[team_id] = images
            logger.info("WORKER:   Team %s has %d images", team.name, len(images))

        _update_progress(f"Preparing fold {task.task_number} data")
        logger.info("=== WORKER: PREPARING FOLD DATA === fold=%d protocol=%s", task.task_number, job.protocol)
        images_dir, gt_path = prepare_fold_data(job, task, images_by_team, teams)
        temp_root = os.path.dirname(images_dir)
        logger.info("WORKER: Fold data prepared: images_dir=%s gt_path=%s", images_dir, gt_path)

        model_dir = None
        try:
            model_dir = tempfile.mkdtemp(prefix="axon_model_")
            model_zip_path = os.path.join(model_dir, "model.zip")
            storage_path = str(model.storage_path)  # type: ignore[arg-type]
            _update_progress("Downloading model zip from storage")
            logger.info("=== WORKER: FETCHING MODEL ZIP === storage_path=%s", storage_path)
            model_bytes = storage_service.get_file(storage_path)
            logger.info("WORKER: Fetched model zip: %d bytes (empty=%s)", len(model_bytes), len(model_bytes) == 0)
            with open(model_zip_path, "wb") as f:
                f.write(model_bytes)
            logger.info("WORKER: Model zip written to %s", model_zip_path)

            timeout = int(os.getenv("EVAL_DOCKER_TIMEOUT", "1800"))
            memory_limit = os.getenv("EVAL_DOCKER_MEMORY_LIMIT", "4g")
            cpu_limit = os.getenv("EVAL_DOCKER_CPU_LIMIT", "2")
            gpu_enabled = os.getenv("EVAL_GPU_ENABLE", "false").lower() == "true"
            gpu_device = os.getenv("CUDA_VISIBLE_DEVICES") if gpu_enabled else None
            _update_progress(f"Docker config: timeout={timeout}s memory={memory_limit} cpu={cpu_limit}")
            logger.info("WORKER: Docker config: timeout=%ds memory=%s cpu=%s gpu=%s",
                         timeout, memory_limit, cpu_limit, gpu_device if gpu_enabled else "disabled")

            _update_progress("Running Docker evaluation (building image, installing deps...)")
            logger.info("=== WORKER: RUNNING DOCKER EVALUATION ===")
            predictions = run_docker_evaluation(
                model_zip_path=model_zip_path,
                data_dir=images_dir,
                task_id=task_id,
                timeout=timeout,
                memory_limit=memory_limit,
                cpu_limit=cpu_limit,
                gpus=gpu_device,
                progress_callback=lambda msg: _update_progress(msg),
            )
            _update_progress(f"Docker returned {len(predictions)} predictions")
            logger.info("WORKER: Docker evaluation returned %d predictions", len(predictions))

            with open(gt_path, "r") as f:
                ground_truth = json.load(f)
            _update_progress(f"Computing metrics on {len(ground_truth)} ground truth entries")
            logger.info("WORKER: Ground truth has %d entries", len(ground_truth))

            logger.info("=== WORKER: COMPUTING METRICS ===")
            metrics = compute_metrics(ground_truth, predictions, progress_callback=lambda msg: _update_progress(msg))
            _update_progress(f"Metrics: accuracy={metrics['accuracy']:.4f} f1={metrics['f1_score']:.4f}")
            logger.info("WORKER: Metrics computed: accuracy=%.4f precision=%.4f recall=%.4f f1=%.4f",
                         metrics["accuracy"], metrics["precision"], metrics["recall"], metrics["f1_score"])

            _update_progress("Recording evaluation result")
            repo.record_evaluation_result(
                evaluation_id=UUID(str(job.id)),
                task_id=task_uuid,
                fold_number=int(str(task.task_number)),
                metrics=metrics,
            )
            logger.info("WORKER: Evaluation result recorded")

            task.status = TaskStatus.completed.value  # type: ignore[assignment]
            task.completed_at = datetime.utcnow()  # type: ignore[assignment]
            _update_progress("Completed", TaskStatus.completed)
            logger.info("WORKER: Task status set to COMPLETED")

            _check_job_completion(UUID(str(job.id)), repo, db)

        finally:
            shutil.rmtree(temp_root, ignore_errors=True)
            logger.info("WORKER: Cleaned up temp_root=%s", temp_root)
            if model_dir:
                shutil.rmtree(model_dir, ignore_errors=True)
                logger.info("WORKER: Cleaned up model_dir=%s", model_dir)

    except Exception as exc:
        logger.exception(f"Evaluation task {task_id} failed")
        try:
            task_uuid = UUID(task_id)
            task = db.query(EvaluationTask).filter(EvaluationTask.id == task_uuid).first()
            if task:
                task.status = TaskStatus.failed.value  # type: ignore[assignment]
                task.error_message = str(exc)  # type: ignore[assignment]
                task.status_detail = f"FAILED: {str(exc)[:200]}"  # type: ignore[assignment]
                db.commit()

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
        logger.warning("CHECK_JOB: Job %s not found", evaluation_id)
        return

    total = getattr(job, 'total_folds', 0)
    logger.info("CHECK_JOB: job=%s completed=%d/%d folds", evaluation_id, completed_folds, total)

    if completed_folds >= total:
        logger.info("=== CHECK_JOB: ALL FOLDS COMPLETE ===")
        results = repo.find_completed_results(evaluation_id)
        if results:
            accuracies = [getattr(r, 'accuracy') for r in results]
            mean_accuracy = sum(accuracies) / len(accuracies)
            logger.info("CHECK_JOB: Mean accuracy=%.4f across %d folds", mean_accuracy, len(results))
            repo.write_final_score(UUID(str(job.model_id)), mean_accuracy)
            logger.info("CHECK_JOB: Final score written for model %s", job.model_id)

        repo.update_evaluation_status(evaluation_id, EvaluationStatus.completed)
        repo.update_evaluation_timestamps(
            evaluation_id, completed_at=datetime.utcnow()
        )
        logger.info("CHECK_JOB: Evaluation status set to COMPLETED")

        model = db.query(Model).filter(Model.id == UUID(str(job.model_id))).first()
        if model:
            from app.models.model_model import ModelStatus
            model.status = ModelStatus.COMPLETED.value  # type: ignore[assignment]
            logger.info("CHECK_JOB: Model %s status set to COMPLETED", job.model_id)
    elif _any_task_failed(evaluation_id, repo):
        logger.warning("CHECK_JOB: Some tasks failed, setting evaluation to FAILED")
        repo.update_evaluation_status(evaluation_id, EvaluationStatus.failed)
    else:
        logger.info("CHECK_JOB: %d/%d folds complete, waiting for remaining", completed_folds, total)


def _any_task_failed(evaluation_id: UUID, repo: EvaluationOrchestrationRepository) -> bool:
    failed = repo.find_failed_tasks(evaluation_id)
    return len(failed) > 0
