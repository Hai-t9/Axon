from app.core.exceptions import NotFoundError, ValidationError
from uuid import UUID, uuid4
from app.models import RoleType
from app.schemas.competition import CompetitionCreate, CompetitionUpdate

from .repository import CompetitionRepository


class CompetitionService:
    def __init__(self, repository: CompetitionRepository):
        self.repository = repository

    def create_competition(self, host_id, payload: CompetitionCreate):
        if self.repository.get_by_name(payload.name):
            raise ValidationError("Competition name already exists")

        competition = self.repository.create(
            {
                "name": payload.name,
                "description": payload.description,
                "launch_date": payload.launch_date,
                "invitation_link": str(uuid4()),
            }
        )

        config_data = (
            payload.config.dict(exclude_unset=True) if payload.config else {}
        )
        config = self.repository.create_config(competition.id, config_data)
        competition.config = config

        self.repository.create_role(host_id, competition.id, RoleType.host)

        return competition

    def get_competition(self, competition_id: UUID):
        competition = self.repository.get_by_id(competition_id)
        if not competition:
            raise NotFoundError("Competition not found")
        return competition

    def list_competitions(self, user_id, page: int, limit: int):
        offset = (page - 1) * limit
        items = self.repository.list_competitions_for_user(user_id, offset, limit)
        total = self.repository.count_competitions_for_user(user_id)
        return items, total

    def update_competition(self, competition_id: UUID, payload: CompetitionUpdate):
        competition = self.get_competition(competition_id)
        updates = payload.dict(exclude_unset=True)
        return self.repository.update(competition, updates)

    def delete_competition(self, competition_id: UUID) -> UUID:
        competition = self.get_competition(competition_id)
        self.repository.delete(competition)
        return competition_id

    def get_competition_config(self, competition_id: UUID):
        config = self.repository.get_config(competition_id)
        if not config:
            raise NotFoundError("Competition config not found")
        return config

    def update_competition_config(self, competition_id: UUID, updates: dict):
        config = self.repository.get_config(competition_id)
        if not config:
            config = self.repository.create_config(competition_id, updates)
            return config

        return self.repository.update_config(config, updates)

    def join_competition(self, user_id: UUID, invitation_link: str):
        """Join a competition via invitation link. User's email must be in a team."""
        competition = self.repository.get_by_invitation_link(invitation_link.strip())
        if not competition:
            raise NotFoundError("Invalid invitation link")

        existing_role = self.repository.get_role(user_id, competition.id)
        if existing_role:
            return competition  # already joined

        # Look up the user's email
        user = self.repository.get_user_by_email_by_id(user_id)
        if not user:
            raise NotFoundError("User not found")

        user_email = user.email.strip().lower()

        # Check if user's email is in any team for this competition
        teams = self.repository.get_teams_for_competition(competition.id)
        found_team = None
        for team in teams:
            emails_dict = team.user_emails or {}
            if user_email in {k.lower() for k in emails_dict.keys()}:
                found_team = team
                break

        if not found_team:
            raise ValidationError(
                "You are not a member of any team in this competition. "
                "Ask the host to add your email to a team first."
            )

        # Mark member as joined
        emails_dict = {k.lower(): v for k, v in (found_team.user_emails or {}).items()}
        emails_dict[user_email] = 1
        found_team.user_emails = emails_dict
        from sqlalchemy.orm.attributes import flag_modified
        flag_modified(found_team, "user_emails")

        self.repository.create_role(user_id, competition.id, RoleType.participant)
        return competition

    def leave_competition(self, user_id: UUID, competition_id: UUID) -> dict:
        """Leave a competition. Sets user_emails status to 0 and removes the participant role."""
        competition = self.get_competition(competition_id)

        existing_role = self.repository.get_role(user_id, competition.id)
        if not existing_role:
            raise ValidationError("You are not a member of this competition.")

        user = self.repository.get_user_by_email_by_id(user_id)
        if not user:
            raise NotFoundError("User not found")

        user_email = user.email.strip().lower()

        teams = self.repository.get_teams_for_competition(competition.id)
        found_team = None
        for team in teams:
            emails_dict = team.user_emails or {}
            if user_email in {k.lower() for k in emails_dict.keys()}:
                found_team = team
                break

        if found_team:
            emails_dict = {k.lower(): v for k, v in (found_team.user_emails or {}).items()}
            emails_dict[user_email] = 0
            found_team.user_emails = emails_dict
            from sqlalchemy.orm.attributes import flag_modified
            flag_modified(found_team, "user_emails")

        self.repository.remove_role(user_id, competition.id)
        return {"left": True, "competition_id": str(competition.id)}

