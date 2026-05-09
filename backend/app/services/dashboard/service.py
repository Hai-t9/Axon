from app.core.exceptions import NotFoundError
from uuid import UUID

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

    def _serialize_config_participant(self, config) -> dict:
        return {
            "labels": config.labels,
            "data_ex": config.data_ex,
            "overview": config.overview,
            "terms_conditions": config.terms_conditions,
            "data_md": config.data_md,
            "data_format": config.data_format,
        }

    def _serialize_team(self, team) -> dict:
        return {
            "id": team.id,
            "name": team.name,
            "comp_id": team.comp_id,
            "user_emails": team.user_emails,
        }

    def _serialize_team_with_stats(self, team) -> dict:
        # Per-team aggregates
        image_stats = self.repository.find_team_image_stats(team.id)
        device_stats = self.repository.find_team_device_stats(team.id)
        label_distribution = self.repository.find_team_label_distribution(team.id)

        return {
            "id": team.id,
            "name": team.name,
            "comp_id": team.comp_id,
            "user_emails": team.user_emails,
            "device_stats": device_stats,
            "label_distribution": label_distribution,
            "images_uploaded": image_stats.get("total", 0) if isinstance(image_stats, dict) else 0,
        }


    def _build_dashboard_payload(self, comp_id: UUID) -> dict:
        phase_info = self.repository.ensure_phase_info(comp_id)

        config = self.repository.find_config(comp_id)

        image_stats = self.repository.find_image_stats(comp_id)
        teams = self.repository.find_team_info(comp_id)
        device_stats = self.repository.find_device_stats(comp_id)
        label_distribution = self.repository.find_label_distribution(comp_id)
        locations = self.repository.find_locations(comp_id)

        return {
            "phase_info": self._serialize_phase_info(phase_info),
            "config": self._serialize_config(config) if config else None,
            "image_stats": image_stats,
            "team_info": {
                "items": [self._serialize_team_with_stats(team) for team in teams],
                "total": len(teams),
            },
            "device_stats": device_stats,
            "label_distribution": label_distribution,
            "locations": locations,
        }

    def _build_participant_payload(self, comp_id: UUID, participant_id: UUID) -> dict:
        phase_info = self.repository.ensure_phase_info(comp_id)

        config = self.repository.find_config(comp_id)

        team = self.repository.find_team_for_participant(comp_id, participant_id)
        if not team:
            raise NotFoundError("Participant team not found")

        image_stats = self.repository.find_team_image_stats(team.id)
        device_stats = self.repository.find_team_device_stats(team.id)
        label_distribution = self.repository.find_team_label_distribution(team.id)
        locations = self.repository.find_team_locations(team.id)

        return {
            "phase_info": self._serialize_phase_info(phase_info),
            "config": self._serialize_config_participant(config) if config else None,
            "image_stats": image_stats,
            "team_info": self._serialize_team_with_stats(team),
            "device_stats": device_stats,
            "label_distribution": label_distribution,
            "locations": locations,
        }

    def get_dashboard(self, comp_id: UUID) -> dict:
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

    def get_participant_dashboard(self, comp_id: UUID, participant_id: UUID) -> dict:
        return self._build_participant_payload(comp_id, participant_id)

    def get_cached_dashboard(self, comp_id: UUID) -> dict:
        cached = self.cache.get_dashboard(comp_id)
        if not cached:
            raise NotFoundError("Cached dashboard not found")
        return cached

    def clear_dashboard_cache(self, comp_id: UUID) -> dict:
        self.cache.clear_dashboard(comp_id)
        return {"cleared": True}
