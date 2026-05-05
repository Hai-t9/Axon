from app.core.exceptions import NotFoundError, ValidationError
from app.schemas.team import TeamCreate, TeamUpdate

from .repository import TeamRepository


class TeamService:
    def __init__(self, repository: TeamRepository):
        self.repository = repository

    def _normalize_user_ids(self, user_ids):
        # Stored as JSON in the Team model, so normalize to a list of ints.
        if not user_ids:
            return []
        normalized = [int(user_id) for user_id in user_ids]
        return list(dict.fromkeys(normalized))

    def create_team(self, comp_id: int, payload: TeamCreate):
        if self.repository.get_by_name(comp_id, payload.name):
            raise ValidationError("Team name already exists in competition")

        user_ids = self._normalize_user_ids(payload.user_ids)
        return self.repository.create(
            {"comp_id": comp_id, "name": payload.name, "user_ids": user_ids}
        )

    def get_team(self, team_id: int):
        team = self.repository.get_by_id(team_id)
        if not team:
            raise NotFoundError("Team not found")
        return team

    def list_teams(self, comp_id: int, page: int, limit: int):
        offset = (page - 1) * limit
        items = self.repository.list_by_competition(comp_id, offset, limit)
        total = self.repository.count_by_competition(comp_id)
        return items, total

    def update_team(self, team_id: int, payload: TeamUpdate):
        team = self.get_team(team_id)
        updates = payload.dict(exclude_unset=True)
        if "user_ids" in updates:
            updates["user_ids"] = self._normalize_user_ids(updates["user_ids"])
        return self.repository.update(team, updates)

    def delete_team(self, team_id: int) -> int:
        team = self.get_team(team_id)
        self.repository.delete(team)
        return team_id

    def add_member(self, team_id: int, user_id: int):
        team = self.get_team(team_id)
        if not self.repository.get_user_by_id(user_id):
            raise ValidationError("User not found")

        user_ids = self._normalize_user_ids(team.user_ids)
        if user_id in user_ids:
            raise ValidationError("User already in team")

        user_ids.append(user_id)
        return self.repository.set_team_members(team, user_ids)

    def remove_member(self, team_id: int, user_id: int):
        team = self.get_team(team_id)
        user_ids = self._normalize_user_ids(team.user_ids)
        if user_id not in user_ids:
            raise ValidationError("User not in team")

        user_ids.remove(user_id)
        return self.repository.set_team_members(team, user_ids)

    def get_members(self, team_id: int):
        team = self.get_team(team_id)
        members = self.repository.get_team_members(team)
        return members

    def get_statistics(self, team_id: int):
        self.get_team(team_id)
        total_members = len(self._normalize_user_ids(self.get_team(team_id).user_ids))
        images_uploaded = self.repository.count_images_by_team(team_id)
        models_submitted = self.repository.count_models_by_team(team_id)
        return {
            "total_members": total_members,
            "images_uploaded": images_uploaded,
            "models_submitted": models_submitted,
        }

