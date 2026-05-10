import logging
from datetime import datetime
from statistics import stdev
from typing import Optional
from uuid import UUID

from app.core.exceptions import NotFoundError, ValidationError
from app.models.model_enums import EvaluationProtocol, EvaluationStatus, TaskStatus
from app.models.model_model import ModelStatus

from .repository import EvaluationOrchestrationRepository

logger = logging.getLogger(__name__)


class EvaluationOrchestrationService:
    def __init__(self, repository: EvaluationOrchestrationRepository):
        self.repository = repository

    # ------------------------------------------------------------------ #
    #  Schedule Evaluation                                                 #
    # ------------------------------------------------------------------ #

    def scheduleEvaluation(
        self,
        model_id: UUID,
        protocol: str,
        requested_folds: Optional[int] = None,
    ) -> dict:
        model = self.repository.find_model_by_id(model_id)
        if not model:
            raise NotFoundError(f"Model {model_id} not found.")
        if model.status != ModelStatus.SCHEDULED.value:
            raise ValidationError(
                f"Cannot evaluate model in '{model.status}' status. "
                "Model must be in SCHEDULED status."
            )

        competition_id = UUID(str(model.competition_id))
        teams = self.repository.find_teams_by_competition(competition_id)
        total_folds = self._determine_fold_count(protocol, teams, requested_folds)

        job = self.repository.create_evaluation_job(
            model_id=model_id,
            competition_id=competition_id,
            protocol=protocol,
            total_folds=total_folds,
        )
        job_id = UUID(str(job.id))
        tasks = self.repository.create_evaluation_tasks(job_id, total_folds)

        self._queue_tasks(job, tasks, protocol)

        model.status = ModelStatus.QUEUED.value  # type: ignore[assignment]

        return {
            "id": str(job.id),
            "model_id": str(job.model_id),
            "competition_id": str(job.competition_id),
            "protocol": str(job.protocol),
            "status": str(job.status),
            "total_folds": job.total_folds,
            "completed_folds": job.completed_folds,
            "retry_count": job.retry_count,
            "max_retries": job.max_retries,
            "created_at": job.created_at,
            "started_at": job.started_at,
            "completed_at": job.completed_at,
        }

    def _determine_fold_count(
        self,
        protocol: str,
        teams: list,
        requested_folds: Optional[int] = None,
    ) -> int:
        parsed = EvaluationProtocol(protocol)
        if parsed == EvaluationProtocol.standard:
            folds = requested_folds or 5
            if folds < 2:
                raise ValidationError("Standard K-Fold requires at least 2 folds.")
            return folds

        team_count = len(teams)
        if parsed == EvaluationProtocol.loto:
            if team_count < 2:
                raise ValidationError(
                    "Leave-One-Team-Out requires at least 2 teams in the competition."
                )
            return team_count

        if parsed == EvaluationProtocol.toto:
            if team_count < 1:
                raise ValidationError(
                    "Train-On-One-Team-Only requires at least 1 team in the competition."
                )
            if requested_folds is not None:
                raise ValidationError(
                    "The 'folds' parameter is not supported for TOTO protocol. "
                    "Fold count is derived from the number of teams."
                )
            return team_count

        raise ValidationError(f"Unknown evaluation protocol: {protocol}")

    # ------------------------------------------------------------------ #
    #  Evaluation Status & Results                                         #
    # ------------------------------------------------------------------ #

    def getEvaluationStatus(self, evaluation_id: UUID) -> dict:
        job = self.repository.find_evaluation_by_id(evaluation_id)
        if not job:
            raise NotFoundError(f"Evaluation {evaluation_id} not found.")

        total = getattr(job, 'total_folds') or 1
        completed = getattr(job, 'completed_folds') or 0
        progress = completed / total

        return {
            "id": str(job.id),
            "model_id": str(job.model_id),
            "status": str(job.status),
            "total_folds": total,
            "completed_folds": completed,
            "progress": progress,
            "created_at": job.created_at,
            "started_at": job.started_at,
            "completed_at": job.completed_at,
        }

    def getEvaluationStatusByModel(self, model_id: UUID) -> dict:
        job = self.repository.find_evaluation_by_model_id(model_id)
        if not job:
            raise NotFoundError(f"No evaluation found for model {model_id}.")
        return self.getEvaluationStatus(UUID(str(job.id)))

    def getEvaluationResults(self, evaluation_id: UUID) -> dict:
        job = self.repository.find_evaluation_by_id(evaluation_id)
        if not job:
            raise NotFoundError(f"Evaluation {evaluation_id} not found.")

        results = self.repository.find_completed_results(evaluation_id)
        if not results:
            raise ValidationError(
                f"No results available for evaluation {evaluation_id}. "
                "The evaluation may not have completed yet."
            )

        aggregated = self._aggregate_metrics(results)
        folds = [
            {
                "fold_number": getattr(r, 'fold_number'),
                "accuracy": getattr(r, 'accuracy'),
                "precision": getattr(r, 'precision'),
                "recall": getattr(r, 'recall'),
                "f1_score": getattr(r, 'f1_score'),
                "confusion_matrix": getattr(r, 'confusion_matrix'),
                "execution_time_seconds": getattr(r, 'execution_time_seconds'),
            }
            for r in results
        ]

        return {
            "evaluation_id": str(job.id),
            "model_id": str(job.model_id),
            "status": str(job.status),
            "total_folds": job.total_folds,
            **aggregated,
            "folds": folds,
        }

    def _aggregate_metrics(self, results: list) -> dict:
        accuracies = [getattr(r, 'accuracy') for r in results]
        precisions = [getattr(r, 'precision') for r in results]
        recalls = [getattr(r, 'recall') for r in results]
        f1_scores = [getattr(r, 'f1_score') for r in results]

        n = len(results)
        return {
            "mean_accuracy": sum(accuracies) / n,
            "std_accuracy": stdev(accuracies) if n > 1 else 0.0,
            "mean_precision": sum(precisions) / n,
            "std_precision": stdev(precisions) if n > 1 else 0.0,
            "mean_recall": sum(recalls) / n,
            "std_recall": stdev(recalls) if n > 1 else 0.0,
            "mean_f1": sum(f1_scores) / n,
            "std_f1": stdev(f1_scores) if n > 1 else 0.0,
        }

    # ------------------------------------------------------------------ #
    #  Retry Logic                                                         #
    # ------------------------------------------------------------------ #

    def retryFailedEvaluation(self, evaluation_id: UUID) -> dict:
        job = self.repository.find_evaluation_by_id(evaluation_id)
        if not job:
            raise NotFoundError(f"Evaluation {evaluation_id} not found.")
        job_status = str(job.status)
        if job_status != EvaluationStatus.failed.value:
            raise ValidationError(
                f"Cannot retry evaluation in '{job_status}' status. "
                "Only failed evaluations can be retried."
            )
        retry_count = getattr(job, 'retry_count') or 0
        max_retries = getattr(job, 'max_retries')
        if retry_count >= max_retries:
            raise ValidationError(
                f"Retry limit ({max_retries}) exhausted for evaluation {evaluation_id}."
            )

        failed_tasks = self.repository.find_failed_tasks(evaluation_id)
        if not failed_tasks:
            raise ValidationError(
                f"No failed tasks found for evaluation {evaluation_id}."
            )

        job_id = UUID(str(job.id))
        for task in failed_tasks:
            task_id = UUID(str(task.id))
            self.repository.update_task_status(task_id, TaskStatus.pending, error=None)

        self.repository.increment_retry_counter(evaluation_id)
        self.repository.update_evaluation_status(job_id, EvaluationStatus.queued)

        return {
            "evaluation_id": str(job_id),
            "retry_count": retry_count + 1,
            "restarted": True,
        }

    # ------------------------------------------------------------------ #
    #  Competition Results (Leaderboard Integration)                       #
    # ------------------------------------------------------------------ #

    def getCompetitionEvaluations(self, comp_id: UUID) -> list:
        return self.repository.find_evaluations_by_competition(comp_id)

    def getCompetitionResults(self, comp_id: UUID) -> dict:
        jobs = self.repository.find_evaluations_by_competition(comp_id)
        team_best: dict[str, dict] = {}

        for job in jobs:
            if str(job.status) != EvaluationStatus.completed.value:
                continue

            job_id = UUID(str(job.id))
            results = self.repository.find_completed_results(job_id)
            if not results:
                continue

            model = self.repository.find_model_by_id(UUID(str(job.model_id)))
            if not model:
                continue

            team = self.repository.find_team_by_id(UUID(str(model.team_id)))
            if not team:
                continue

            accuracies = [getattr(r, 'accuracy') for r in results]
            mean_acc = sum(accuracies) / len(accuracies)

            team_id_str = str(team.id)
            existing = team_best.get(team_id_str)
            if existing is None or mean_acc > existing["mean_accuracy"]:
                team_best[team_id_str] = {
                    "team_id": team_id_str,
                    "team_name": str(team.name),
                    "model_id": str(job.model_id),
                    "mean_accuracy": mean_acc,
                    "protocol": str(job.protocol),
                    "evaluation_id": str(job.id),
                }

        final_rankings = sorted(
            team_best.values(),
            key=lambda x: x["mean_accuracy"],
            reverse=True,
        )

        return {
            "competition_id": str(comp_id),
            "final_rankings": final_rankings,
        }

    # ------------------------------------------------------------------ #
    #  Task Queueing                                                       #
    # ------------------------------------------------------------------ #

    def _queue_tasks(self, job, tasks: list, protocol: str) -> None:
        job_id = UUID(str(job.id))
        try:
            from app.workers.evaluation_worker import run_evaluation_task  # type: ignore[import]

            for task in tasks:
                task_id = UUID(str(task.id))
                run_evaluation_task.delay(str(task_id))
                self.repository.update_task_status(task_id, TaskStatus.queued)
            self.repository.update_evaluation_status(job_id, EvaluationStatus.queued)
        except Exception:
            logger.warning(
                "Celery/Redis unavailable — falling back to queued (polling) mode."
            )
            for task in tasks:
                task_id = UUID(str(task.id))
                self.repository.update_task_status(task_id, TaskStatus.queued)
            self.repository.update_evaluation_status(job_id, EvaluationStatus.queued)
