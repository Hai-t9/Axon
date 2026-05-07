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
        raw_url = os.getenv("REDIS_URL")
        # treat empty string as not configured
        self.redis_url = raw_url.strip() if raw_url and raw_url.strip() else None
        self.ttl_seconds = int(os.getenv("DASHBOARD_CACHE_TTL_SECONDS", "900"))
        self.client = self._build_client()

    def _build_client(self):
        if redis is None:
            return None
        if not self.redis_url:
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
        raw_url = os.getenv("REDIS_URL")
        self.redis_url = raw_url.strip() if raw_url and raw_url.strip() else None
        self.ttl_seconds = int(os.getenv("VALIDATION_CACHE_TTL_SECONDS", "0"))
        self.client = self._build_client()

    def _build_client(self):
        if redis is None:
            return None
        if not self.redis_url:
            return None
        try:
            client = redis.Redis.from_url(self.redis_url, decode_responses=True)
            client.ping()
            return client
        except Exception:
            return None

    def _team_key(self, comp_id: int, participant_id: int) -> str:
        return f"validation:team:{comp_id}:{participant_id}"

    def _threshold_key(self, comp_id: int) -> str:
        return f"validation:threshold:{comp_id}"

    def get_participant_team_id(self, comp_id: int, participant_id: int) -> int | None:
        if not self.client:
            return None
        raw = self.client.get(self._team_key(comp_id, participant_id))
        if not raw:
            return None
        try:
            return int(raw)
        except (TypeError, ValueError):
            return None

    def set_participant_team_id(self, comp_id: int, participant_id: int, team_id: int) -> bool:
        if not self.client:
            return False
        key = self._team_key(comp_id, participant_id)
        if self.ttl_seconds > 0:
            self.client.setex(key, self.ttl_seconds, str(team_id))
        else:
            self.client.set(key, str(team_id))
        return True

    def get_validation_threshold(self, comp_id: int) -> int | None:
        if not self.client:
            return None
        raw = self.client.get(self._threshold_key(comp_id))
        if not raw:
            return None
        try:
            return int(raw)
        except (TypeError, ValueError):
            return None

    def set_validation_threshold(self, comp_id: int, threshold: int) -> bool:
        if not self.client:
            return False
        key = self._threshold_key(comp_id)
        if self.ttl_seconds > 0:
            self.client.setex(key, self.ttl_seconds, str(threshold))
        else:
            self.client.set(key, str(threshold))
        return True


@lru_cache(maxsize=1)
def get_validation_cache() -> ValidationCache:
    return ValidationCache()
