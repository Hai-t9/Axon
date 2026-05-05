from app.core.exceptions import NotFoundError

from app.core.cache import DashboardCache
from .repository import DashboardRepository


class DashboardService:
    def __init__(self, repository: DashboardRepository, cache: DashboardCache):
        self.repository = repository
        self.cache = cache

    def _serialize_phase_info(self, phase_info) -> dict:
        return {
            "competition_id": phase_info.competition_id,
            "current_phase": phase_info.current_phase,
            "phase_dates": phase_info.phase_dates or {},
        }

    def _serialize_config(self, config) -> dict:
        return {
            "id": config.id,
            "competition_id": config.competition_id,
            "labels": config.labels,
            "data_ex": config.data_ex,
            "scoring_ex": config.scoring_ex,
            "overview": config.overview,
            "terms_conditions": config.terms_conditions,
            "data_md": config.data_md,
            "data_format": config.data_format,
            "evaluation": config.evaluation,
            "duplicate_threshhold": config.duplicate_threshhold,
            "max_validations": config.max_validations,
        }

    def _serialize_team(self, team) -> dict:
        return {
            "id": team.id,
            "name": team.name,
            "comp_id": team.comp_id,
            "user_ids": team.user_ids,
        }

    def _build_dashboard_payload(self, comp_id: int) -> dict:
        phase_info = self.repository.find_phase_info(comp_id)
        if not phase_info:
            raise NotFoundError("Phase information not found")

        config = self.repository.find_config(comp_id)
        if not config:
            raise NotFoundError("Competition config not found")

        image_stats = self.repository.find_image_stats(comp_id)
        teams = self.repository.find_team_info(comp_id)

        return {
            "phase_info": self._serialize_phase_info(phase_info),
            "config": self._serialize_config(config),
            "image_stats": image_stats,
            "team_info": {
                "items": [self._serialize_team(team) for team in teams],
                "total": len(teams),
            },
        }

    def get_dashboard(self, comp_id: int) -> dict:
        # 1. Try cache first
        cached = self.cache.get_dashboard(comp_id)
        if cached:
            cached_payload = cached.get("data")
            if isinstance(cached_payload, dict):
                return cached_payload
        # 2. If not cached → fetch from DB
        payload = self._build_dashboard_payload(comp_id)
        # 3. Store in cache
        self.cache.set_dashboard(comp_id, payload)
        return payload

    def get_cached_dashboard(self, comp_id: int) -> dict:
        cached = self.cache.get_dashboard(comp_id)
        if not cached:
            raise NotFoundError("Cached dashboard not found")
        return cached

    def clear_dashboard_cache(self, comp_id: int) -> dict:
        self.cache.clear_dashboard(comp_id)
        return {"cleared": True}
