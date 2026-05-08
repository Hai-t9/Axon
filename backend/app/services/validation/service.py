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

    def _deterministic_shuffle(self, image_ids: list[int], participant_id: UUID) -> list[int]:
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

        threshold = self.repository.find_validation_threshold(comp_id) or 5

        # Initialize per-team buckets
        team_assignments: dict[UUID, list[int]] = {team.id: [] for team in teams}

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
            raise NotFoundError("Validation list not found")

        shuffled = self._deterministic_shuffle(image_ids, participant_id)
        return {"image_ids": shuffled}

    def submit_vote(self, image_id: int, validator_id: UUID, label: str) -> dict:
        vote = self.repository.insert_vote(image_id, validator_id, label)
        if not vote:
            raise ValidationError("Vote could not be recorded")

        threshold = self.repository.find_validation_threshold(
            self.label_service.get_competition_id(image_id)
        ) or 5

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

    def get_pending_validations(self, comp_id: UUID) -> dict:
        images = self.repository.find_pending_by_comp(comp_id)
        return {"images": images, "total": len(images)}
