from collections import Counter
import random
from uuid import UUID

from app.core.exceptions import NotFoundError, ValidationError
from app.services.label.service import LabelService

from .repository import ValidationRepository


class ValidationService:
    def __init__(self, repository: ValidationRepository, label_service: LabelService):
        self.repository = repository
        self.label_service = label_service

    def _compute_majority_vote(self, votes: list[str]) -> str:
        if not votes:
            raise ValidationError("No votes to compute majority")
        counts = Counter(votes)
        return sorted(counts.items(), key=lambda item: (-item[1], item[0]))[0][0]

    def _deterministic_shuffle(self, image_ids: list[UUID], participant_id: UUID) -> list[UUID]:
        shuffled = list(image_ids)
        random.Random(str(participant_id)).shuffle(shuffled)
        return shuffled

    def generate_assignments(self, comp_id: UUID) -> dict:
        """
        Round-Robin assignment ensures every image reaches exactly the threshold.
        Cycles through teams, assigning each image repeatedly until it has been
        assigned threshold times in total.
        """
        teams = self.repository.fetch_all_teams(comp_id)
        if not teams:
            raise NotFoundError("No teams found for competition")

        images = self.repository.fetch_all_competition_images(comp_id)
        if not images:
            raise NotFoundError("No images found for competition")

        threshold = self.repository.find_validation_threshold(comp_id) or 3

        # Initialize per-team buckets
        team_assignments: dict[UUID, list[UUID]] = {team.id: [] for team in teams}

        # Round-Robin: for each image, assign it threshold times across teams
        team_index = 0
        for image_id in images:
            for _ in range(threshold):
                team = teams[team_index % len(teams)]
                team_assignments[team.id].append(image_id)
                team_index += 1

        # Store each team's list in Redis
        for team in teams:
            self.repository.store_team_assignments(team.id, team_assignments[team.id])

        return {"success": True}

    def get_validation_list(self, comp_id: UUID, participant_id: UUID) -> dict:
        team_id = self.repository.find_participant_team(comp_id, participant_id)
        if not team_id:
            raise NotFoundError("Participant team not found")

        image_ids = self.repository.get_team_assignments(team_id)
        if not image_ids:
            self.generate_assignments(comp_id)
            image_ids = self.repository.get_team_assignments(team_id)
            if not image_ids:
                return {"images": [], "total": 0}

        # Filter out already-validated images
        unvalidated_ids = self.repository.filter_unvalidated_images(image_ids)
        
        shuffled = self._deterministic_shuffle(unvalidated_ids, participant_id)
        
        # Fetch details (filepath, current_label) for each image
        details = self.repository.fetch_image_details(shuffled)
        
        images = [
            {
                "image_id": str(img_id),
                "filepath": details[img_id]["filepath"],
                "current_label": details[img_id]["label"],
            }
            for img_id in shuffled
            if img_id in details
        ]
        return {"images": images, "total": len(images)}

    def submit_vote(self, image_id: UUID, validator_id: UUID, label: str) -> dict:
        vote = self.repository.insert_vote(image_id, validator_id, label)
        if not vote:
            raise ValidationError("Vote could not be recorded")

        threshold = self.repository.find_validation_threshold(
            self.label_service.get_competition_id(image_id)
        ) or 3

        vote_count = self.repository.count_votes_for_image(image_id)
        skip_count = self.repository.get_skip_count(image_id)
        
        if vote_count + skip_count >= threshold:
            label_entry = self.repository.find_label_by_image_id(image_id)
            if not label_entry:
                raise NotFoundError("Label not found")

            votes = [entry.label for entry in self.repository.find_votes_by_label_id(label_entry.id)]
            final_label = self._compute_majority_vote(votes)
            self.label_service.update_label(image_id, final_label)
            self.label_service.validate_label(image_id)

        return {"validation_id": str(vote.id), "label": vote.label}

    def skip_image(self, image_id: UUID, participant_id: UUID) -> dict:
        """Handle image skip: remove from queue and increment skip count.
        If skip threshold is reached, auto-validate with original label."""
        comp_id = self.label_service.get_competition_id(image_id)
        
        # Find participant's team
        team_id = self.repository.find_participant_team(comp_id, participant_id)
        if not team_id:
            raise NotFoundError("Participant team not found")

        # Remove image from team's validation queue
        removed = self.repository.remove_from_team_assignment(team_id, image_id)
        if removed == 0:
            raise ValidationError("Image not in your validation queue")

        # Increment skip count
        skip_count = self.repository.increment_skip_count(image_id)
        vote_count = self.repository.count_votes_for_image(image_id)

        # Get validation threshold
        threshold = self.repository.find_validation_threshold(comp_id) or 3

        # If total combined interactions >= threshold, auto-validate with original label or majority votes
        if vote_count + skip_count >= threshold:
            label_entry = self.repository.find_label_by_image_id(image_id)
            if label_entry and not label_entry.validated:
                if vote_count > 0:
                    votes = [entry.label for entry in self.repository.find_votes_by_label_id(label_entry.id)]
                    final_label = self._compute_majority_vote(votes)
                    self.label_service.update_label(image_id, final_label)
                self.label_service.validate_label(image_id)

        return {
            "skip_count": skip_count,
            "threshold": threshold,
            "auto_validated": (vote_count + skip_count) >= threshold
        }

    def get_pending_validations(self, comp_id: UUID) -> dict:
        images = self.repository.find_pending_by_comp(comp_id)
        return {"images": images, "total": len(images)}
