import logging
from collections import Counter
import random
from uuid import UUID

from app.core.exceptions import NotFoundError, ValidationError
from app.services.label.service import LabelService

from .repository import ValidationRepository

logger = logging.getLogger(__name__)


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
        logger.info("[VALIDATION] Generating assignments for competition %s", comp_id)
        teams = self.repository.fetch_all_teams(comp_id)
        if not teams:
            logger.warning("[VALIDATION] No teams found for competition %s", comp_id)
            raise NotFoundError("No teams found for competition")
        logger.info("[VALIDATION] Found %d teams for competition %s", len(teams), comp_id)

        images = self.repository.fetch_all_competition_images(comp_id)
        if not images:
            logger.warning("[VALIDATION] No images found for competition %s", comp_id)
            raise NotFoundError("No images found for competition")
        logger.info("[VALIDATION] Found %d images for competition %s", len(images), comp_id)

        threshold = self.repository.find_validation_threshold(comp_id) or 3
        logger.info("[VALIDATION] Validation threshold=%d for competition %s", threshold, comp_id)

        team_assignments: dict[UUID, list[UUID]] = {team.id: [] for team in teams}
        team_index = 0
        for image_id in images:
            for _ in range(threshold):
                team = teams[team_index % len(teams)]
                team_assignments[team.id].append(image_id)
                team_index += 1

        for team in teams:
            count = len(team_assignments[team.id])
            logger.info(
                "[VALIDATION] Assigning %d images to team %s",
                count, team.id,
            )
            self.repository.store_team_assignments(team.id, team_assignments[team.id])

        logger.info("[VALIDATION] Done generating assignments for competition %s", comp_id)
        return {"success": True}

    def get_validation_list(self, comp_id: UUID, participant_id: UUID) -> dict:
        logger.info(
            "[VALIDATION] get_validation_list called: comp=%s participant=%s",
            comp_id, participant_id,
        )
        team_id = self.repository.find_participant_team(comp_id, participant_id)
        if not team_id:
            logger.warning(
                "[VALIDATION] No team found for participant %s in comp %s",
                participant_id, comp_id,
            )
            raise NotFoundError("Participant team not found")
        logger.info("[VALIDATION] Participant %s belongs to team %s", participant_id, team_id)

        image_ids = self.repository.get_team_assignments(team_id)
        logger.info(
            "[VALIDATION] Team %s has %d assigned images from store",
            team_id, len(image_ids) if image_ids else 0,
        )
        if not image_ids:
            logger.info("[VALIDATION] No stored assignments — generating new ones")
            self.generate_assignments(comp_id)
            image_ids = self.repository.get_team_assignments(team_id)
            logger.info(
                "[VALIDATION] After generation, team %s has %d images",
                team_id, len(image_ids) if image_ids else 0,
            )
            if not image_ids:
                logger.warning("[VALIDATION] Still no images after generation — returning empty")
                return {"images": [], "total": 0}

        unvalidated_ids = self.repository.filter_unvalidated_images(image_ids)
        logger.info(
            "[VALIDATION] %d unvalidated out of %d total assigned images",
            len(unvalidated_ids), len(image_ids),
        )

        shuffled = self._deterministic_shuffle(unvalidated_ids, participant_id)
        logger.debug("[VALIDATION] Shuffled order: %s", [str(i) for i in shuffled[:5]])

        details = self.repository.fetch_image_details(shuffled)
        logger.info(
            "[VALIDATION] Fetched details for %d of %d images",
            len(details), len(shuffled),
        )

        images = [
            {
                "image_id": str(img_id),
                "filepath": details[img_id]["filepath"],
                "current_label": details[img_id]["label"],
            }
            for img_id in shuffled
            if img_id in details
        ]
        logger.info("[VALIDATION] Returning %d images in validation list", len(images))
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
