import uuid
import logging
from typing import Any
from sqlalchemy.orm import Session
from app.core.exceptions import NotFoundError, ValidationError
from .repository import EvaluationRepository

logger = logging.getLogger(__name__)


class EvaluationService:
    def __init__(self, repository: EvaluationRepository):
        self.repository = repository

    def schedule_evaluation(self, model_id: int, protocol: str, db: Session) -> dict[str, Any]:
        model = self.repository.find_model(model_id)
        if not model:
            raise NotFoundError(f"Model {model_id} not found")

        if protocol not in ("standard", "loto", "toto"):
            raise ValidationError(f"Unknown protocol '{protocol}'. Use: standard, loto, toto")

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

        try:
            from .docker_runner import evaluate_model

            metrics = evaluate_model(
                model_filepath=model.docker_img_filepath,
                images=images,
                protocol=protocol,
                model_team_id=model.team_id,
            )

            score = metrics["accuracy"]

            # Save evaluation result
            evaluation = self.repository.find_by_model_id(model_id)
            if evaluation:
                self.repository.update_evaluation(evaluation, score)
            else:
                self.repository.create_evaluation(model_id, score)

            db.commit()

            return {
                "model_id": model_id,
                "job_id": job_id,
                "status": "completed",
                "score": score,
                "message": (
                    f"Evaluation completed using {protocol} protocol. "
                    f"Accuracy: {score:.2%} "
                    f"({metrics['correct']}/{metrics['total']} correct, "
                    f"train={metrics['train_count']}, test={metrics['test_count']})"
                ),
            }

        except FileNotFoundError:
            raise ValidationError(
                f"Model file not found at {model.docker_img_filepath}. "
                "Was the model archive uploaded correctly?"
            )
        except RuntimeError as exc:
            logger.error(f"Docker evaluation failed for model {model_id}: {exc}")
            raise ValidationError(f"Evaluation failed: {exc}")
        except Exception as exc:
            logger.exception(f"Unexpected evaluation error for model {model_id}")
            raise ValidationError(f"Evaluation error: {exc}")

    def get_evaluation(self, model_id: int) -> Any:
        evaluation = self.repository.find_by_model_id(model_id)
        if not evaluation:
            raise NotFoundError(f"Evaluation for model {model_id} not found")
        return evaluation

    def store_result(self, model_id: int, score: float) -> Any:
        model = self.repository.find_model(model_id)
        if not model:
            raise NotFoundError(f"Model {model_id} not found")

        evaluation = self.repository.find_by_model_id(model_id)
        if evaluation:
            return self.repository.update_evaluation(evaluation, score)
        else:
            return self.repository.create_evaluation(model_id, score)
