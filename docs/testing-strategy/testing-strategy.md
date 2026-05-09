---
sidebar_position: 1
---

# Testing Strategy

## Test Suite

Tests are located in `backend/tests/`. They use `pytest` with SQLite in-memory databases for fast, isolated runs.

## Test Files

| File | Coverage |
|------|----------|
| `test_auth_flow.py` | Registration, login, JWT auth, role enforcement (competition CRUD, config updates) |
| `test_dashboard_flow.py` | Dashboard retrieval for host/staff |
| `test_dashboard_cache_flow.py` | Redis caching layer for dashboard |
| `test_dashboard_role_flow.py` | Role-based dashboard access |
| `test_evaluation_orchestration_flow.py` | Evaluation scheduling, status, results |
| `test_gateway_middleware.py` | Request ID, rate limiting, security headers |
| `test_label_flow.py` | Label CRUD and validation |
| `test_leaderboard_flow.py` | Leaderboard computation and ranking |
| `test_model_submission_flow.py` | Docker submission validation, dedup, versioning, eligibility |
| `test_validation_flow.py` | Validation assignment, voting, skip, finalization |

## How to Run Tests

```bash
cd backend
pytest tests/ -v

# Run a specific test file
pytest tests/test_auth_flow.py -v

# Run with coverage
pytest tests/ --cov=app
```

## Test Configuration

Tests use an in-memory SQLite database created per test session. The `conftest.py` file sets up the Python path and shared fixtures.
