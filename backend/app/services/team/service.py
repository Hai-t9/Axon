from app.core.exceptions import NotFoundError, ValidationError
from uuid import UUID
import logging
from app.schemas.team import TeamCreate, TeamUpdate

from .repository import TeamRepository

logger = logging.getLogger(__name__)


class TeamService:
    def __init__(self, repository: TeamRepository):
        self.repository = repository

    def _normalize_user_ids(self, user_ids):
        # Stored as JSON in the Team model, so normalize to a list of ints.
        if not user_ids:
            return []
        normalized = [str(user_id) for user_id in user_ids]
        return list(dict.fromkeys(normalized))

    def create_team(self, comp_id: UUID, payload: TeamCreate):
        if self.repository.get_by_name(comp_id, payload.name):
            raise ValidationError("Team name already exists in competition")

        user_ids = self._normalize_user_ids(payload.user_ids)
        return self.repository.create(
            {"comp_id": comp_id, "name": payload.name, "user_ids": user_ids}
        )

    def get_team(self, team_id: UUID):
        team = self.repository.get_by_id(team_id)
        if not team:
            raise NotFoundError("Team not found")
        return team

    def list_teams(self, comp_id: UUID, page: int, limit: int):
        offset = (page - 1) * limit
        items = self.repository.list_by_competition(comp_id, offset, limit)
        total = self.repository.count_by_competition(comp_id)
        return items, total

    def update_team(self, team_id: UUID, payload: TeamUpdate):
        team = self.get_team(team_id)
        updates = payload.dict(exclude_unset=True)
        if "user_ids" in updates:
            updates["user_ids"] = self._normalize_user_ids(updates["user_ids"])
        return self.repository.update(team, updates)

    def delete_team(self, team_id: UUID) -> UUID:
        team = self.get_team(team_id)
        self.repository.delete(team)
        return team_id

    def add_member(self, team_id: UUID, user_id: UUID):
        team = self.get_team(team_id)
        if not self.repository.get_user_by_id(user_id):
            raise ValidationError("User not found")

        user_ids = self._normalize_user_ids(team.user_ids)
        user_id_str = str(user_id)
        if user_id_str in user_ids:
            raise ValidationError("User already in team")

        user_ids.append(user_id_str)
        return self.repository.set_team_members(team, user_ids)

    def remove_member(self, team_id: UUID, user_id: UUID):
        team = self.get_team(team_id)
        user_ids = self._normalize_user_ids(team.user_ids)
        user_id_str = str(user_id)
        if user_id_str not in user_ids:
            raise ValidationError("User not in team")

        user_ids.remove(user_id_str)
        return self.repository.set_team_members(team, user_ids)

    def get_members(self, team_id: UUID):
        team = self.get_team(team_id)
        members = self.repository.get_team_members(team)
        return members

    def add_member_by_email(self, team_id: UUID, email: str):
        user = self.repository.get_user_by_email(email)
        if not user:
            raise NotFoundError(f"User with email '{email}' not found")
        return self.add_member(team_id, user.id)

    def get_statistics(self, team_id: UUID):
        self.get_team(team_id)
        total_members = len(self._normalize_user_ids(self.get_team(team_id).user_ids))
        images_uploaded = self.repository.count_images_by_team(team_id)
        models_submitted = self.repository.count_models_by_team(team_id)
        return {
            "total_members": total_members,
            "images_uploaded": images_uploaded,
            "models_submitted": models_submitted,
        }

    def bulk_create_teams(self, comp_id: UUID, teams_data: dict) -> dict:
        """Create multiple teams from a dict of {team_name: [email1, email2, ...]}"""
        logger.info(f"bulk_create_teams called for comp {comp_id} with {len(teams_data)} teams")
        logger.info(f"teams_data: {teams_data}")
        created = []
        errors = []
        for team_name, member_emails in teams_data.items():
            logger.info(f"Processing team '{team_name}' with emails: {member_emails}")
            if self.repository.get_by_name(comp_id, team_name):
                errors.append(f"Team '{team_name}' already exists")
                continue

            user_ids = []
            for email in member_emails:
                clean = email.strip().lstrip("@")
                logger.info(f"Resolving email '{email}' -> cleaned '{clean}'")
                user = self.repository.get_user_by_email(clean)
                if user:
                    user_ids.append(str(user.id))
                    logger.info(f"Resolved '{clean}' -> user {user.id}")
                else:
                    errors.append(f"User '{clean}' not found")
                    logger.warning(f"User '{clean}' not found in database")

            team = self.repository.create(
                {"comp_id": comp_id, "name": team_name, "user_ids": user_ids}
            )
            created.append({
                "id": str(team.id),
                "name": team.name,
                "comp_id": str(team.comp_id),
                "user_ids": team.user_ids
            })

        return {"created": created, "errors": errors}

