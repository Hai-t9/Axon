import logging
from uuid import UUID

from app.core.exceptions import NotFoundError, ValidationError
from app.schemas.team import TeamCreate, TeamUpdate

from .repository import TeamRepository

logger = logging.getLogger(__name__)


class TeamService:
    def __init__(self, repository: TeamRepository):
        self.repository = repository

    def _normalize_emails(self, user_emails) -> dict:
        """Normalize user_emails to a dict of {email_lower: 0|1}."""
        if not user_emails:
            return {}
        if isinstance(user_emails, dict):
            return {k.strip().lower(): int(1 if v else 0) for k, v in user_emails.items()}
        return {}

    def create_team(self, comp_id: UUID, payload: TeamCreate):
        if self.repository.get_by_name(comp_id, payload.name):
            raise ValidationError("Team name already exists in competition")

        user_emails = self._normalize_emails(payload.user_emails)
        return self.repository.create(
            {"comp_id": comp_id, "name": payload.name, "user_emails": user_emails or {}}
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
        if "user_emails" in updates and updates["user_emails"] is not None:
            updates["user_emails"] = self._normalize_emails(updates["user_emails"])
        return self.repository.update(team, updates)

    def delete_team(self, team_id: UUID) -> UUID:
        team = self.get_team(team_id)
        self.repository.delete(team)
        return team_id

    def add_member_by_email(self, team_id: UUID, email: str):
        """Add a member email to the team (status=0 by default)."""
        team = self.get_team(team_id)
        email_lower = email.strip().lower()
        if not email_lower:
            raise ValidationError("Email is required")

        user_emails = self._normalize_emails(team.user_emails)
        if email_lower in user_emails:
            raise ValidationError("Email already in team")

        user_emails[email_lower] = 0
        return self.repository.set_user_emails(team, user_emails)

    def remove_member_by_email(self, team_id: UUID, email: str):
        """Remove a member email from the team."""
        team = self.get_team(team_id)
        email_lower = email.strip().lower()

        user_emails = self._normalize_emails(team.user_emails)
        if email_lower not in user_emails:
            raise ValidationError("Email not in team")

        del user_emails[email_lower]
        return self.repository.set_user_emails(team, user_emails)

    def set_member_joined(self, team_id: UUID, email: str, joined: int):
        """Set the joined status for a member email."""
        team = self.get_team(team_id)
        email_lower = email.strip().lower()

        user_emails = self._normalize_emails(team.user_emails)
        if email_lower not in user_emails:
            raise ValidationError("Email not in team")

        user_emails[email_lower] = joined
        return self.repository.set_user_emails(team, user_emails)

    def get_members(self, team_id: UUID):
        """Get full user objects for team members with their join status."""
        team = self.get_team(team_id)
        email_status = self._normalize_emails(team.user_emails)
        if not email_status:
            return []
        users = self.repository.get_members_by_emails(list(email_status.keys()))
        email_to_user = {u.email.strip().lower(): u for u in users}
        result = []
        for email, status in email_status.items():
            user = email_to_user.get(email)
            if user:
                result.append({
                    "id": user.id,
                    "fullname": user.fullname,
                    "email": user.email,
                    "phone": user.phone,
                    "created_at": user.created_at,
                    "joined": status,
                })
            else:
                result.append({
                    "id": "",
                    "fullname": email,
                    "email": email,
                    "phone": None,
                    "created_at": None,
                    "joined": status,
                })
        return result

    def get_statistics(self, team_id: UUID):
        team = self.get_team(team_id)
        total_members = len(self._normalize_emails(team.user_emails))
        images_uploaded = self.repository.count_images_by_team(team_id)
        models_submitted = self.repository.count_models_by_team(team_id)
        return {
            "total_members": total_members,
            "images_uploaded": images_uploaded,
            "models_submitted": models_submitted,
        }

    def bulk_create_teams(self, comp_id: UUID, teams_data: dict) -> dict:
        """Create multiple teams from a dict of {team_name: [email1, email2, ...]}"""
        logger.info(
            f"bulk_create_teams called for comp {comp_id} with {len(teams_data)} teams"
        )
        created = []
        errors = []
        for team_name, member_emails in teams_data.items():
            if self.repository.get_by_name(comp_id, team_name):
                errors.append(f"Team '{team_name}' already exists")
                continue

            user_emails = {}
            for email in member_emails:
                clean = email.strip().lower().lstrip("@")
                if clean:
                    user_emails[clean] = 0

            team = self.repository.create(
                {"comp_id": comp_id, "name": team_name, "user_emails": user_emails}
            )
            created.append(
                {
                    "id": str(team.id),
                    "name": team.name,
                    "comp_id": str(team.comp_id),
                    "user_emails": team.user_emails,
                }
            )

        return {"created": created, "errors": errors}
