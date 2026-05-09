from app.core.exceptions import NotFoundError, ValidationError
from uuid import UUID, uuid4
from app.models import RoleType
from app.schemas.competition import CompetitionCreate, CompetitionUpdate

from .repository import CompetitionRepository

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
        """Join a competition via invitation link. User must be in a team."""
        competition = self.repository.get_by_invitation_link(invitation_link.strip())
        if not competition:
            raise NotFoundError("Invalid invitation link")

        existing_role = self.repository.get_role(user_id, competition.id)
        if existing_role:
            return competition  # already joined

        # Check if user is in any team for this competition
        teams = self.repository.get_teams_for_competition(competition.id)
        user_id_str = str(user_id)
        in_team = False
        for team in teams:
            member_ids = team.user_ids or []
            if user_id_str in member_ids:
                in_team = True
                break

        if not in_team:
            raise ValidationError(
                "You are not a member of any team in this competition. "
                "Ask the host to add your email to a team first."
            )

        self.repository.create_role(user_id, competition.id, RoleType.participant)
        return competition
