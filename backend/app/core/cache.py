import json
import os
from datetime import datetime
from functools import lru_cache
from typing import Any

try:
    import redis
except ImportError:  # pragma: no cover - optional dependency during scaffold stage
    redis = None


class DashboardCache:
    def __init__(self):
        self.redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
        self.ttl_seconds = int(os.getenv("DASHBOARD_CACHE_TTL_SECONDS", "900"))
        self.client = self._build_client()

    def _build_client(self):
        if redis is None:
            return None
        try:
            client = redis.Redis.from_url(self.redis_url, decode_responses=True)
            client.ping()
            return client
        except Exception:
            return None

    def _key(self, comp_id: int) -> str:
        return f"dashboard:{comp_id}"

    def get_dashboard(self, comp_id: int) -> dict[str, Any] | None:
        if not self.client:
            return None
        raw = self.client.get(self._key(comp_id))
        if not raw:
            return None
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            return None
        if not isinstance(parsed, dict):
            return None
        return parsed

    def set_dashboard(self, comp_id: int, data: dict[str, Any]) -> bool:
        if not self.client:
            return False
        payload = {
            "cached_at": datetime.utcnow().isoformat(),
            "data": data,
        }
        raw = json.dumps(payload)
        if self.ttl_seconds > 0:
            self.client.setex(self._key(comp_id), self.ttl_seconds, raw)
        else:
            self.client.set(self._key(comp_id), raw)
        return True

    def clear_dashboard(self, comp_id: int) -> bool:
        if not self.client:
            return False
        deleted = self.client.delete(self._key(comp_id))
        return bool(deleted)


@lru_cache(maxsize=1)
def get_dashboard_cache() -> DashboardCache:
    return DashboardCache()


class ValidationCache:
    def __init__(self):
        self.redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
        self.client = self._build_client()
        # These rarely change during competition, so 1 hour TTL is fine
        self.ttl_seconds = 3600

    def _build_client(self):
        if redis is None:
            return None
        try:
            client = redis.Redis.from_url(self.redis_url, decode_responses=True)
            client.ping()
            return client
        except Exception:
            return None
            
    def get_threshold(self, comp_id: int) -> int | None:
        if not self.client: return None
        val = self.client.get(f"val_thresh:{comp_id}")
        return int(val) if val else None
        
    def set_threshold(self, comp_id: int, threshold: int):
        if self.client:
            self.client.setex(f"val_thresh:{comp_id}", self.ttl_seconds, str(threshold))
            
    def get_participant_team(self, comp_id: int, user_id: int) -> int | None:
        if not self.client: return None
        val = self.client.get(f"val_team:{comp_id}:{user_id}")
        return int(val) if val else None
        
    def set_participant_team(self, comp_id: int, user_id: int, team_id: int):
        if self.client:
            self.client.setex(f"val_team:{comp_id}:{user_id}", self.ttl_seconds, str(team_id))


@lru_cache(maxsize=1)
def get_validation_cache() -> ValidationCache:
    return ValidationCache()

