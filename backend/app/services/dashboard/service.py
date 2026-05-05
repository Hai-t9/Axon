from app.core.exceptions import NotFoundError

from .repository import DashboardRepository


class DashboardService:
    def __init__(self, repository: DashboardRepository):
        self.repository = repository

    def get_dashboard(self, comp_id: int) -> dict:
        phase_info = self.repository.find_phase_info(comp_id)
        if not phase_info:
            raise NotFoundError("Phase information not found")

        config = self.repository.find_config(comp_id)
        if not config:
            raise NotFoundError("Competition config not found")

        image_stats = self.repository.find_image_stats(comp_id)
        teams = self.repository.find_team_info(comp_id)

        return {
            "phase_info": phase_info,
            "config": config,
            "image_stats": image_stats,
            "team_info": {
                "items": teams,
                "total": len(teams),
            },
        }
