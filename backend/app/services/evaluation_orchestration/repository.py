from typing import List, Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.models import (
    Evaluation,
    EvaluationJob,
    EvaluationResult,
    EvaluationTask,
    Image,
    Model,
    Team,
)
from app.models.model_enums import EvaluationStatus, TaskStatus


class EvaluationOrchestrationRepository:
    def __init__(self, db: Session):
        self.db = db

    # ------------------------------------------------------------------ #
    #  EvaluationJob CRUD                                                  #
    # ------------------------------------------------------------------ #

    def create_evaluation_job(
        self,
        model_id: UUID,
        competition_id: UUID,
        protocol: str,
        total_folds: int,
    ) -> EvaluationJob:
        job = EvaluationJob(
            model_id=model_id,
            competition_id=competition_id,
            protocol=protocol,
            total_folds=total_folds,
        )
        self.db.add(job)
        self.db.flush()
        return job

    def find_evaluation_by_id(self, evaluation_id: UUID) -> Optional[EvaluationJob]:
        return (
            self.db.query(EvaluationJob)
            .filter(EvaluationJob.id == evaluation_id)
            .first()
        )

    def find_evaluation_by_model_id(self, model_id: UUID) -> Optional[EvaluationJob]:
        return (
            self.db.query(EvaluationJob)
            .filter(EvaluationJob.model_id == model_id)
            .first()
        )

    def find_evaluations_by_competition(self, comp_id: UUID) -> List[EvaluationJob]:
        return (
            self.db.query(EvaluationJob)
            .filter(EvaluationJob.competition_id == comp_id)
            .all()
        )

    def update_evaluation_status(
        self, evaluation_id: UUID, status: EvaluationStatus
    ) -> EvaluationJob:
        job = self.find_evaluation_by_id(evaluation_id)
        if job:
            job.status = status.value  # type: ignore[assignment]
            self.db.flush()
        return job

    def update_evaluation_timestamps(
        self,
        evaluation_id: UUID,
        started_at=None,
        completed_at=None,
    ) -> EvaluationJob:
        job = self.find_evaluation_by_id(evaluation_id)
        if job:
            if started_at is not None:
                job.started_at = started_at
            if completed_at is not None:
                job.completed_at = completed_at
            self.db.flush()
        return job

    def increment_completed_folds(self, evaluation_id: UUID) -> int:
        job = self.find_evaluation_by_id(evaluation_id)
        if job:
            current = job.completed_folds if job.completed_folds is not None else 0
            job.completed_folds = current + 1  # type: ignore[assignment]
            self.db.flush()
            return job.completed_folds  # type: ignore[return-value]
        return 0

    def increment_retry_counter(self, evaluation_id: UUID) -> int:
        job = self.find_evaluation_by_id(evaluation_id)
        if job:
            current = job.retry_count if job.retry_count is not None else 0
            job.retry_count = current + 1  # type: ignore[assignment]
            self.db.flush()
            return job.retry_count  # type: ignore[return-value]
        return 0

    # ------------------------------------------------------------------ #
    #  EvaluationTask CRUD                                                 #
    # ------------------------------------------------------------------ #

    def create_evaluation_tasks(
        self, evaluation_id: UUID, count: int
    ) -> List[EvaluationTask]:
        tasks = []
        for i in range(count):
            task = EvaluationTask(
                evaluation_id=evaluation_id,
                task_number=i,
            )
            self.db.add(task)
            tasks.append(task)
        self.db.flush()
        return tasks

    def find_tasks_by_evaluation(self, evaluation_id: UUID) -> List[EvaluationTask]:
        return (
            self.db.query(EvaluationTask)
            .filter(EvaluationTask.evaluation_id == evaluation_id)
            .order_by(EvaluationTask.task_number)
            .all()
        )

    def find_pending_tasks(self, evaluation_id: UUID) -> List[EvaluationTask]:
        return (
            self.db.query(EvaluationTask)
            .filter(
                EvaluationTask.evaluation_id == evaluation_id,
                EvaluationTask.status == "pending",
            )
            .all()
        )

    def find_failed_tasks(self, evaluation_id: UUID) -> List[EvaluationTask]:
        return (
            self.db.query(EvaluationTask)
            .filter(
                EvaluationTask.evaluation_id == evaluation_id,
                EvaluationTask.status == "failed",
            )
            .all()
        )

    def update_task_status(
        self,
        task_id: UUID,
        status: TaskStatus,
        worker_id: Optional[str] = None,
        error: Optional[str] = None,
    ) -> EvaluationTask:
        task = (
            self.db.query(EvaluationTask).filter(EvaluationTask.id == task_id).first()
        )
        if task:
            task.status = status.value  # type: ignore[assignment]
            if worker_id is not None:
                task.worker_id = worker_id  # type: ignore[assignment]
            if error is not None:
                task.error_message = error  # type: ignore[assignment]
            self.db.flush()
        return task

    # ------------------------------------------------------------------ #
    #  EvaluationResult CRUD                                               #
    # ------------------------------------------------------------------ #

    def record_evaluation_result(
        self,
        evaluation_id: UUID,
        task_id: UUID,
        fold_number: int,
        metrics: dict,
    ) -> EvaluationResult:
        result = EvaluationResult(
            evaluation_id=evaluation_id,
            task_id=task_id,
            fold_number=fold_number,
            accuracy=metrics["accuracy"],
            precision=metrics["precision"],
            recall=metrics["recall"],
            f1_score=metrics["f1_score"],
            confusion_matrix=metrics.get("confusion_matrix"),
            execution_time_seconds=metrics.get("execution_time_seconds"),
        )
        self.db.add(result)
        self.db.flush()
        return result

    def find_completed_results(self, evaluation_id: UUID) -> List[EvaluationResult]:
        return (
            self.db.query(EvaluationResult)
            .filter(EvaluationResult.evaluation_id == evaluation_id)
            .order_by(EvaluationResult.fold_number)
            .all()
        )

    # ------------------------------------------------------------------ #
    #  Cross-module reads                                                  #
    # ------------------------------------------------------------------ #

    def find_model_by_id(self, model_id: UUID) -> Optional[Model]:
        return self.db.query(Model).filter(Model.id == model_id).first()

    def find_team_by_id(self, team_id: UUID) -> Optional[Team]:
        return self.db.query(Team).filter(Team.id == team_id).first()

    def find_teams_by_competition(self, comp_id: UUID) -> List[Team]:
        return self.db.query(Team).filter(Team.comp_id == comp_id).all()

    def find_images_by_team(self, team_id: UUID) -> List[Image]:
        return self.db.query(Image).filter(Image.team_id == team_id).all()

    def write_final_score(self, model_id: UUID, score: float) -> None:
        existing = (
            self.db.query(Evaluation).filter(Evaluation.model_id == model_id).first()
        )
        if existing:
            existing.score = score  # type: ignore[assignment]
        else:
            eval_row = Evaluation(model_id=model_id, score=score)
            self.db.add(eval_row)
        self.db.flush()
