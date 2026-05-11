import logging
import json
import os
from datetime import datetime
from functools import lru_cache
from typing import Any

try:
    import redis
except ImportError:  # pragma: no cover - optional dependency during scaffold stage
    redis = None

logger = logging.getLogger(__name__)


def _try_build_redis_client(url: str | None, label: str = "Redis"):
    if redis is None:
        logger.warning("[%s] redis-py not installed", label)
        return None
    if not url:
        logger.warning("[%s] No URL configured", label)
        return None
    for attempt, ssl_kwargs in enumerate([
        {"ssl_cert_reqs": None},
        {},
    ]):
        try:
            client = redis.Redis.from_url(url, decode_responses=True, **ssl_kwargs)
            client.ping()
            logger.info("[%s] Connected successfully (attempt %d, ssl_cert_reqs=%s)", label, attempt + 1, ssl_kwargs.get("ssl_cert_reqs"))
            return client
        except Exception as e:
            logger.warning("[%s] Connection attempt %d failed: %s", label, attempt + 1, e)
    logger.error("[%s] All connection attempts to %s failed", label, url)
    return None


class DashboardCache:
    def __init__(self):
        raw_url = os.getenv("REDIS_URL")
        # treat empty string as not configured
        self.redis_url = raw_url.strip() if raw_url and raw_url.strip() else None
        self.ttl_seconds = int(os.getenv("DASHBOARD_CACHE_TTL_SECONDS", "900"))
        self.client = self._build_client()

    def _build_client(self):
        return _try_build_redis_client(self.redis_url, "DashboardCache")

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
        raw = json.dumps(payload, default=str)
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
        return _try_build_redis_client(self.redis_url, "ValidationCache")


@lru_cache(maxsize=1)
def get_validation_cache() -> ValidationCache:
    return ValidationCache()
