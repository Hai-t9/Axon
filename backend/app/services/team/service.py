from app.core.exceptions import NotFoundError, ValidationError
from uuid import UUID
import logging
from app.schemas.team import TeamCreate, TeamUpdate

from .repository import TeamRepository

logger = logging.getLogger(__name__)


class TeamService:
    def __init__(self, repository: TeamRepository):
        self.repository = repository

    def _normalize_emails(self, user_emails) -> dict:
        """Normalize user_emails to a dict of {email_lower: bool}."""
        if not user_emails:
            return {}
        if isinstance(user_emails, dict):
            return {k.strip().lower(): bool(v) for k, v in user_emails.items()}
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
        """Add a member email to the team (status=false by default)."""
        team = self.get_team(team_id)
        email_lower = email.strip().lower()
        if not email_lower:
            raise ValidationError("Email is required")

        user_emails = self._normalize_emails(team.user_emails)
        if email_lower in user_emails:
            raise ValidationError("Email already in team")

        user_emails[email_lower] = False
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

    def set_member_joined(self, team_id: UUID, email: str, joined: bool):
        """Set the joined status for a member email."""
        team = self.get_team(team_id)
        email_lower = email.strip().lower()

        user_emails = self._normalize_emails(team.user_emails)
        if email_lower not in user_emails:
            raise ValidationError("Email not in team")

        user_emails[email_lower] = joined
        return self.repository.set_user_emails(team, user_emails)

    def get_members(self, team_id: UUID):
        """Get full user objects for team members that exist in the system."""
        team = self.get_team(team_id)
        user_emails = self._normalize_emails(team.user_emails)
        if not user_emails:
            return []
        return self.repository.get_members_by_emails(list(user_emails.keys()))

    def add_member_by_email(self, team_id: UUID, email: str):
        user = self.repository.get_user_by_email(email)
        if not user:
            raise NotFoundError(f"User with email '{email}' not found")
        return self.add_member(team_id, user.id)

    def get_statistics(self, team_id: UUID):
        team = self.get_team(team_id)
        user_emails = self._normalize_emails(team.user_emails)
        total_members = len(user_emails)
        images_uploaded = self.repository.count_images_by_team(team_id)
        models_submitted = self.repository.count_models_by_team(team_id)
        
        member_stats = []
        members = self.repository.get_members_by_emails(list(user_emails.keys()))
        for member in members:
            uploads = self.repository.count_images_by_user_in_team(team_id, member.id)
            validations = self.repository.count_validations_by_user_in_team(team_id, member.id)
            member_stats.append({
                "user_id": str(member.id),
                "name": member.fullname or "Unknown",
                "email": member.email,
                "images_uploaded": uploads,
                "images_validated": validations,
            })
            
        return {
            "total_members": total_members,
            "images_uploaded": images_uploaded,
            "models_submitted": models_submitted,
            "members": member_stats,
        }

    def bulk_create_teams(self, comp_id: UUID, teams_data: dict) -> dict:
        """Create multiple teams from a dict of {team_name: [email1, email2, ...]}"""
        logger.info(f"bulk_create_teams called for comp {comp_id} with {len(teams_data)} teams")
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
                    user_emails[clean] = False

            team = self.repository.create(
                {"comp_id": comp_id, "name": team_name, "user_emails": user_emails}
            )
            created.append({
                "id": str(team.id),
                "name": team.name,
                "comp_id": str(team.comp_id),
                "user_emails": team.user_emails,
            })

        return {"created": created, "errors": errors}
