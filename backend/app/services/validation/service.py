from collections import Counter
from math import floor
import random
from uuid import UUID

from app.core.exceptions import NotFoundError, ValidationError
from app.services.label.service import LabelService

from .repository import ValidationRepository


class ValidationService:
    def __init__(self, repository: ValidationRepository, label_service: LabelService):
        self.repository = repository
        self.label_service = label_service

    def _should_pick_own_team(self, own_count: int, other_count: int) -> bool:
        ratio = own_count / (own_count + other_count + 1)
        return ratio < 0.6

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
        teams = self.repository.fetch_all_teams(comp_id)
        if not teams:
            raise NotFoundError("No teams found for competition")

        assigned_counts: dict[int, int] = {}

        for team in teams:
            threshold = self.repository.find_validation_threshold(comp_id) or 5
            team_own_images = self.repository.count_team_images(comp_id, team.id)
            available_own = self.repository.fetch_available_own_images(
                comp_id,
                team.id,
                assigned_counts,
                threshold,
            )

            own_quota = floor(min(team_own_images, available_own) * 0.6)
            other_quota = floor(own_quota / 0.6 * 0.4) if own_quota > 0 else 0

            own_images = self.repository.fetch_own_images(
                comp_id,
                team.id,
                own_quota,
                assigned_counts,
                threshold,
            )
            other_images = self.repository.fetch_other_images(
                comp_id,
                team.id,
                other_quota,
                assigned_counts,
                threshold,
            )

            master_image_ids = own_images + other_images
            self.repository.store_team_assignments(team.id, master_image_ids)

            participants = self.repository.fetch_participants_by_team(team.id)
            for participant_id in participants:
                shuffled = self._deterministic_shuffle(master_image_ids, participant_id)
                self.repository.store_participant_assignments(participant_id, shuffled)

        return {"success": True}

    def get_validation_list(self, comp_id: UUID, participant_id: UUID) -> dict:
        image_ids = self.repository.get_participant_assignments(participant_id)
        if not image_ids:
            self.generate_assignments(comp_id)
            image_ids = self.repository.get_participant_assignments(participant_id)

        return {"image_ids": image_ids}

    def get_next_image(self, comp_id: UUID, participant_id: UUID) -> dict:
        team = self.repository.find_participant_team(comp_id, participant_id)
        if not team:
            raise NotFoundError("Participant team not found")

        threshold = self.repository.find_validation_threshold(comp_id) or 5
        counts = self.repository.count_participant_validations(comp_id, participant_id, team.id)
        pick_own_team = self._should_pick_own_team(counts["ownCount"], counts["otherCount"])

        if pick_own_team:
            image = self.repository.find_next_from_own_team(
                comp_id, team.id, participant_id, threshold
            )
        else:
            image = self.repository.find_next_from_other_teams(
                comp_id, team.id, participant_id, threshold
            )

        if not image:
            raise NotFoundError("No eligible images found")

        return image

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
