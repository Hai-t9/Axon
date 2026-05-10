import os
import time

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.gateway import (
    RateLimitMiddleware,
    RequestIDMiddleware,
    RequestLoggingMiddleware,
    SecurityHeadersMiddleware,
)

# Prevent tests from using the shared Upstash Redis (set by .env via dotenv)
# so each test gets an isolated in-memory rate limit store instead.
os.environ.pop("REDIS_URL", None)


def _make_app(*middlewares):
    app = FastAPI()

    for mw in middlewares:
        app.add_middleware(mw)

    @app.get("/test")
    async def test_endpoint():
        return {"ok": True}

    @app.get("/health")
    async def health():
        return {"status": "ok"}

    return app


class TestRequestIDMiddleware:
    def test_adds_request_id_header(self):
        app = _make_app(RequestIDMiddleware)
        client = TestClient(app)
        resp = client.get("/test")
        assert resp.status_code == 200
        assert "x-request-id" in resp.headers
        assert len(resp.headers["x-request-id"]) == 12

    def test_preserves_existing_request_id(self):
        app = _make_app(RequestIDMiddleware)
        client = TestClient(app)
        resp = client.get("/test", headers={"X-Request-ID": "my-custom-id"})
        assert resp.headers["x-request-id"] == "my-custom-id"

    def test_different_requests_get_different_ids(self):
        app = _make_app(RequestIDMiddleware)
        client = TestClient(app)
        r1 = client.get("/test")
        r2 = client.get("/test")
        assert r1.headers["x-request-id"] != r2.headers["x-request-id"]


class TestRequestLoggingMiddleware:
    def test_does_not_crash(self):
        app = _make_app(RequestLoggingMiddleware)
        client = TestClient(app)
        resp = client.get("/test")
        assert resp.status_code == 200

    def test_logs_health_endpoint(self):
        app = _make_app(RequestLoggingMiddleware)
        client = TestClient(app)
        resp = client.get("/health")
        assert resp.status_code == 200


class TestRateLimitMiddleware:
    def test_allows_requests_under_limit(self):
        app = _make_app(
            lambda app: RateLimitMiddleware(app, max_requests=100, window_seconds=60)
        )
        client = TestClient(app)
        for _ in range(10):
            resp = client.get("/test")
            assert resp.status_code == 200

    def test_blocks_requests_over_limit(self):
        app = _make_app(
            lambda app: RateLimitMiddleware(app, max_requests=2, window_seconds=60)
        )
        client = TestClient(app)

        assert client.get("/test").status_code == 200
        assert client.get("/test").status_code == 200
        resp = client.get("/test")
        assert resp.status_code == 429
        assert resp.json()["detail"] == "Too many requests. Please try again later."
        assert "retry-after" in resp.headers

    def test_skips_rate_limit_for_health(self):
        app = _make_app(
            lambda app: RateLimitMiddleware(app, max_requests=1, window_seconds=60)
        )
        client = TestClient(app)

        assert client.get("/health").status_code == 200
        assert client.get("/health").status_code == 200
        assert client.get("/health").status_code == 200

    def test_different_methods_have_separate_counters(self):
        app = _make_app(
            lambda app: RateLimitMiddleware(app, max_requests=1, window_seconds=60)
        )

        @app.post("/test")
        async def test_post():
            return {"ok": True}

        client = TestClient(app)

        assert client.get("/test").status_code == 200
        assert client.post("/test").status_code == 200


class TestSecurityHeadersMiddleware:
    def test_adds_security_headers(self):
        app = _make_app(SecurityHeadersMiddleware)
        client = TestClient(app)
        resp = client.get("/test")
        assert resp.headers.get("x-content-type-options") == "nosniff"
        assert resp.headers.get("x-frame-options") == "DENY"
        assert resp.headers.get("content-security-policy") == "default-src 'none'"

    def test_does_not_overwrite_existing_headers(self):
        app = FastAPI()
        app.add_middleware(SecurityHeadersMiddleware)

        @app.get("/custom")
        async def custom():
            from fastapi.responses import Response
            return Response(
                content='{"ok": true}',
                headers={"x-content-type-options": "custom"},
            )

        client = TestClient(app)
        resp = client.get("/custom")
        assert resp.headers.get("x-content-type-options") == "custom"


class TestFullMiddlewareStack:
    def test_all_middlewares_together(self):
        app = _make_app(
            lambda app: RequestIDMiddleware(app),
            lambda app: RequestLoggingMiddleware(app),
            lambda app: RateLimitMiddleware(app, max_requests=100, window_seconds=60),
            lambda app: SecurityHeadersMiddleware(app),
        )
        client = TestClient(app)

        resp = client.get("/test", headers={"X-Request-ID": "integration-test"})
        assert resp.status_code == 200
        assert resp.headers.get("x-request-id") == "integration-test"
        assert resp.headers.get("x-content-type-options") == "nosniff"
        assert resp.headers.get("x-frame-options") == "DENY"

    def test_health_bypasses_rate_limit_in_full_stack(self):
        app = _make_app(
            lambda app: RequestIDMiddleware(app),
            lambda app: RequestLoggingMiddleware(app),
            lambda app: RateLimitMiddleware(app, max_requests=1, window_seconds=60),
            lambda app: SecurityHeadersMiddleware(app),
        )
        client = TestClient(app)

        assert client.get("/test").status_code == 200
        assert client.get("/health").status_code == 200
        assert client.get("/health").status_code == 200


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
