from collections import Counter

from app.core.exceptions import NotFoundError, ValidationError
from app.services.label.service import LabelService

from .repository import ValidationRepository


class ValidationService:
    def __init__(self, repository: ValidationRepository, label_service: LabelService):
        self.repository = repository
        self.label_service = label_service

    def get_next_image(self, comp_id: int, participant_id: int) -> dict:
        if self.repository.is_dataset_locked(comp_id):
            return {"image": None}

        team = self.repository.find_participant_team(comp_id, participant_id)
        if not team:
            raise NotFoundError("Participant team not found")

        threshold = self.repository.find_validation_threshold(comp_id)
        if not threshold:
            threshold = 1

        counts = self.repository.count_participant_validations(comp_id, participant_id, team.id)
        own_count = counts["ownCount"]
        other_count = counts["otherCount"]
        
        # Decide pool based on 60/40 ratio (pure logic, no DB):
        # if ownCount / (ownCount + otherCount + 1) < 0.6 -> own team
        # else -> other teams
        ratio = own_count / (own_count + other_count + 1)
        
        if ratio < 0.6:
            images = self.repository.find_batch_from_own_team(
                comp_id, team.id, participant_id, threshold, 1
            )
            if not images:
                # Fallback if own team has no more images
                images = self.repository.find_batch_from_other_teams(
                    comp_id, team.id, participant_id, threshold, 1
                )
        else:
            images = self.repository.find_batch_from_other_teams(
                comp_id, team.id, participant_id, threshold, 1
            )
            if not images:
                # Fallback if other teams have no more images
                images = self.repository.find_batch_from_own_team(
                    comp_id, team.id, participant_id, threshold, 1
                )

        return {"image": images[0] if images else None}

    def submit_vote(self, image_id: int, validator_id: int, label: str) -> dict:
        comp_id = self.label_service.get_competition_id(image_id)
        if self.repository.is_dataset_locked(comp_id):
            raise ValidationError("Dataset is locked. Modifications are no longer allowed.")

        vote = self.repository.insert_vote(image_id, validator_id, label)
        if not vote:
            raise ValidationError("Vote could not be recorded")

        threshold = self.repository.find_validation_threshold(
            self.label_service.get_competition_id(image_id)
        )
        if not threshold:
            threshold = 1

        vote_count = self.repository.count_votes_for_image(image_id)
        if vote_count >= threshold:
            label_entry = self.repository.find_label_by_image_id(image_id)
            if not label_entry:
                raise NotFoundError("Label not found")

            votes = [entry.label for entry in self.repository.find_votes_by_label_id(label_entry.id)]
            final_label = self._compute_majority_vote(votes)
            self.label_service.update_label(image_id, final_label)
            self.label_service.validate_label(image_id)

        return {"validation_id": vote.id, "label": vote.label}

    def _compute_majority_vote(self, votes: list[str]) -> str:
        if not votes:
            raise ValidationError("No votes to compute majority")
        counts = Counter(votes)
        return sorted(counts.items(), key=lambda item: (-item[1], item[0]))[0][0]

    def get_pending_validations(self, comp_id: int) -> dict:
        images = self.repository.find_pending_by_comp(comp_id)
        return {"images": images, "total": len(images)}
