from app.core.exceptions import NotFoundError, ValidationError
from app.models import RoleType
from app.schemas.competition import CompetitionCreate, CompetitionUpdate

from .repository import CompetitionRepository


class CompetitionService:
    def __init__(self, repository: CompetitionRepository):
        self.repository = repository

    def create_competition(self, host_id: int, payload: CompetitionCreate):
        if self.repository.get_by_name(payload.name):
            raise ValidationError("Competition name already exists")

        competition = self.repository.create(
            {
                "name": payload.name,
                "description": payload.description,
                "launch_date": payload.launch_date,
            }
        )

        config_data = (
            payload.config.dict(exclude_unset=True) if payload.config else {}
        )
        config = self.repository.create_config(competition.id, config_data)
        competition.config = config

        self.repository.create_role(host_id, competition.id, RoleType.host)

        # Create initial phase log so dashboard works immediately
        from app.models import PhaseLog
        phase_log = PhaseLog(
            competition_id=competition.id,
            current_phase="creation",
            phase_dates={},
        )
        self.repository.db.add(phase_log)
        self.repository.db.commit()

        return competition

    def get_competition(self, competition_id: int):
        competition = self.repository.get_by_id(competition_id)
        if not competition:
            raise NotFoundError("Competition not found")
        return competition

    def list_competitions(self, page: int, limit: int, user_id: int | None = None):
        offset = (page - 1) * limit
        items = self.repository.list_competitions(offset, limit, user_id=user_id)
        total = self.repository.count_competitions(user_id=user_id)
        return items, total

    def update_competition(self, competition_id: int, payload: CompetitionUpdate):
        competition = self.get_competition(competition_id)
        updates = payload.dict(exclude_unset=True)
        return self.repository.update(competition, updates)

    def delete_competition(self, competition_id: int) -> int:
        competition = self.get_competition(competition_id)
        self.repository.delete(competition)
        return competition_id

    def get_competition_config(self, competition_id: int):
        config = self.repository.get_config(competition_id)
        if not config:
            raise NotFoundError("Competition config not found")
        return config

    def update_competition_config(self, competition_id: int, updates: dict):
        config = self.repository.get_config(competition_id)
        if not config:
            config = self.repository.create_config(competition_id, updates)
            return config

        return self.repository.update_config(config, updates)

