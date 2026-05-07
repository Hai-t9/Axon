import uuid
from typing import Any
from sqlalchemy.orm import Session
from app.core.exceptions import NotFoundError, ValidationError
from .repository import EvaluationRepository

class EvaluationService:
    def __init__(self, repository: EvaluationRepository):
        self.repository = repository

    def schedule_evaluation(self, model_id: int, protocol: str, db: Session) -> dict[str, Any]:
        model = self.repository.find_model(model_id)
        if not model:
            raise NotFoundError(f"Model {model_id} not found")

        job_id = str(uuid.uuid4())
        
        # MOCK: Instantly generate a random score for the MVP showcase
        import random
        score = round(random.uniform(0.60, 0.99), 4)
        
        # Save evaluation result to the database immediately
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
            "message": f"Evaluation completed instantly using {protocol} protocol."
        }

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
