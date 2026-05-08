import uuid
import logging
import json
from typing import Any
from sqlalchemy.orm import Session
from fastapi import BackgroundTasks
from app.core.database import SessionLocal
from app.core.exceptions import NotFoundError, ValidationError
from .repository import EvaluationRepository

logger = logging.getLogger(__name__)


class EvaluationService:
    def __init__(self, repository: EvaluationRepository):
        self.repository = repository

    def schedule_evaluation(self, model_id: int, protocol: str, db: Session, background_tasks: BackgroundTasks) -> dict[str, Any]:
        model = self.repository.find_model(model_id)
        if not model:
            raise NotFoundError(f"Model {model_id} not found")

        if protocol not in ("standard", "loto", "toto", "kfold"):
            raise ValidationError(f"Unknown protocol '{protocol}'. Use: standard, loto, toto, kfold")

        # Get all validated images for the competition
        images = self.repository.get_all_validated_images_for_competition(model.competition_id)

        if not images:
            raise ValidationError(
                "No validated images available. Ensure images have been validated before evaluation."
            )

        if len(images) < 2:
            raise ValidationError(
                f"Only {len(images)} validated image(s). Need at least 2 for evaluation."
            )

        if protocol == "kfold" and len(images) < 5:
            raise ValidationError(
                f"Only {len(images)} validated image(s). Need at least 5 for 5-fold CV evaluation."
            )

        # LOTO/TOTO require images from at least 2 different teams
        if protocol in ("loto", "toto"):
            team_ids_with_data = set(img["team_id"] for img in images)
            if len(team_ids_with_data) < 2:
                raise ValidationError(
                    f"The '{protocol.upper()}' protocol requires images from at least 2 teams, "
                    f"but only {len(team_ids_with_data)} team(s) have validated images. "
                    f"Use the 'standard' protocol instead, or add more teams with validated data."
                )

        job_id = str(uuid.uuid4())

        # Always create a new evaluation attempt
        evaluation = self.repository.create_evaluation(model_id, status="pending")
        db.commit()

        background_tasks.add_task(self._run_evaluation_background, evaluation.id, model.docker_img_filepath, images, protocol, model.team_id)

        return {
            "model_id": model_id,
            "job_id": job_id,
            "status": "pending",
            "message": f"Evaluation queued using {protocol} protocol.",
        }

    def _run_evaluation_background(self, evaluation_id: int, docker_img_filepath: str, images: list, protocol: str, model_team_id: int):
        db = SessionLocal()
        try:
            from .docker_runner import evaluate_model
            
            repo = EvaluationRepository(db)
            from app.models import Evaluation
            evaluation = db.query(Evaluation).filter(Evaluation.id == evaluation_id).first()
            if not evaluation:
                return

            metrics = evaluate_model(
                model_filepath=docker_img_filepath,
                images=images,
                protocol=protocol,
                model_team_id=model_team_id,
            )

            score = metrics.get("accuracy", 0.0)
            metrics_json = json.dumps(metrics)

            repo.update_evaluation(evaluation, score=score, metrics_json=metrics_json, status="completed")

        except Exception as exc:
            logger.exception(f"Background evaluation error for evaluation {evaluation_id}")
            try:
                from app.models import Evaluation
                evaluation = db.query(Evaluation).filter(Evaluation.id == evaluation_id).first()
                if evaluation:
                    repo = EvaluationRepository(db)
                    repo.update_evaluation(evaluation, status="failed")
            except Exception:
                pass
        finally:
            db.close()

    def get_evaluations(self, model_id: int) -> list[Any]:
        return self.repository.find_all_by_model_id(model_id)

    def store_result(self, model_id: int, score: float) -> Any:
        model = self.repository.find_model(model_id)
        if not model:
            raise NotFoundError(f"Model {model_id} not found")

        evaluation = self.repository.find_by_model_id(model_id)
        if evaluation:
            return self.repository.update_evaluation(evaluation, score)
        else:
            return self.repository.create_evaluation(model_id, score)
