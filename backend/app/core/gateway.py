import logging
import os
import time
import uuid

GATEWAY_LOG_LEVEL = os.getenv("GATEWAY_LOG_LEVEL", "INFO").upper()
logger = logging.getLogger("gateway")
logger.setLevel(getattr(logging, GATEWAY_LOG_LEVEL, logging.INFO))
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(
        logging.Formatter("%(asctime)s [%(name)s] %(levelname)s %(message)s")
    )
    logger.addHandler(handler)


class RequestIDMiddleware:
    """Reads or generates X-Request-ID and attaches it to scope state + response."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        headers = dict(scope.get("headers", []))
        req_id = (
            headers.get(b"x-request-id", b"").decode()
            or uuid.uuid4().hex[:12]
        )
        scope.setdefault("state", {})["request_id"] = req_id

        async def wrapped_send(event):
            if event["type"] == "http.response.start":
                event.setdefault("headers", [])
                event["headers"].append((b"x-request-id", req_id.encode()))
            await send(event)

        await self.app(scope, receive, wrapped_send)


class RequestLoggingMiddleware:
    """Logs method, path, status, duration, request_id for every request."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        start = time.monotonic()
        method = scope.get("method", "?")
        path = scope.get("path", "?")
        client = scope.get("client", ("?", 0))[0]
        req_id = scope.get("state", {}).get("request_id", "-")

        status_code = 0

        async def wrapped_send(event):
            nonlocal status_code
            if event["type"] == "http.response.start":
                status_code = event.get("status", 0)
            await send(event)

        await self.app(scope, receive, wrapped_send)

        duration_ms = int((time.monotonic() - start) * 1000)
        logger.info(
            "%s %s %s %dms req=%s client=%s",
            method, path, status_code, duration_ms, req_id, client,
        )


class _InMemoryRateStore:
    def __init__(self):
        self._requests: dict[str, list[float]] = {}

    def is_allowed(self, key: str, max_requests: int, window_seconds: int) -> bool:
        now = time.monotonic()
        cutoff = now - window_seconds
        timestamps = self._requests.get(key, [])
        timestamps = [t for t in timestamps if t > cutoff]
        if len(timestamps) >= max_requests:
            self._requests[key] = timestamps
            return False
        timestamps.append(now)
        self._requests[key] = timestamps
        if len(self._requests) > 10000:
            self._requests = {
                k: [t for t in v if t > cutoff]
                for k, v in self._requests.items()
            }
        return True


class RateLimitMiddleware:
    """Sliding-window rate limiter per IP. Uses Redis if available, else in-memory."""

    def __init__(
        self,
        app,
        max_requests: int = 0,
        window_seconds: int = 60,
    ):
        self.app = app
        self.max_requests = max_requests or int(os.getenv("RATE_LIMIT_REQUESTS", "100"))
        self.window_seconds = window_seconds or int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))
        self._store = _InMemoryRateStore()

        redis_url = os.getenv("REDIS_URL", "")
        self._redis = None
        if redis_url:
            try:
                import redis.asyncio as aioredis
                self._redis = aioredis.from_url(redis_url, decode_responses=True)
            except Exception:
                self._redis = None

    async def _redis_allowed(self, key: str) -> bool | None:
        if self._redis is None:
            return None
        try:
            now = int(time.time())
            window_key = f"ratelimit:{key}:{now // self.window_seconds}"
            pipe = self._redis.pipeline()
            pipe.incr(window_key)
            pipe.expire(window_key, self.window_seconds * 2)
            results = await pipe.execute()
            return results[0] <= self.max_requests
        except Exception:
            return None

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        path = scope.get("path", "")
        if path in ("/health", "/docs", "/openapi.json", "/redoc"):
            await self.app(scope, receive, send)
            return

        client = scope.get("client", ("127.0.0.1", 0))[0]
        key = f"{client}:{scope.get('method', '?')}"

        allowed = await self._redis_allowed(key)
        if allowed is None:
            allowed = self._store.is_allowed(key, self.max_requests, self.window_seconds)

        if not allowed:
            logger.warning("Rate limit exceeded for %s on %s", client, scope.get("path", "?"))
            body = b'{"detail":"Too many requests. Please try again later."}'
            headers = [
                (b"content-type", b"application/json"),
                (b"retry-after", str(self.window_seconds).encode()),
            ]
            await send({
                "type": "http.response.start",
                "status": 429,
                "headers": headers,
            })
            await send({
                "type": "http.response.body",
                "body": body,
            })
            return

        await self.app(scope, receive, send)


class SecurityHeadersMiddleware:
    """Adds security-related HTTP headers to every response."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        async def wrapped_send(event):
            if event["type"] == "http.response.start":
                event.setdefault("headers", [])
                headers = {
                    b"x-content-type-options": b"nosniff",
                    b"x-frame-options": b"DENY",
                    b"content-security-policy": b"default-src 'none'",
                }
                existing = {h[0] for h in event["headers"]}
                for name, value in headers.items():
                    if name not in existing:
                        event["headers"].append((name, value))
            await send(event)

        await self.app(scope, receive, wrapped_send)
