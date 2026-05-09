---
sidebar_position: 1
---

# Development & Setup

## Prerequisites

- Python 3.10+
- Flutter SDK (for frontend)
- Git

## Backend Setup

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # configure your environment variables
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`.

### Environment Variables

Key variables in `backend/.env`:

| Variable | Description | Default |
|---|---|---|
| `DATABASE_URL` | PostgreSQL connection string (Supabase) | `sqlite:///./axon.db` (fallback) |
| `REDIS_URL` | Redis connection for caching/Celery | (optional, empty = disabled) |
| `MINIO_ENDPOINT` | S3-compatible storage endpoint | (optional, empty = local storage) |
| `MINIO_ACCESS_KEY` | MinIO access key | `minioadmin` |
| `MINIO_SECRET_KEY` | MinIO secret key | `minioadmin` |
| `MINIO_BUCKET_NAME` | Storage bucket name | `axon-uploads` |
| `SECRET_KEY` | JWT signing secret | `dev-secret-key-change-in-production` |
| `DEBUG` | Enable debug mode | `True` |
| `EVAL_GPU_ENABLE` | Enable GPU workers | `false` |
| `EVAL_DOCKER_TIMEOUT` | Max seconds per evaluation | `600` |
| `RATE_LIMIT_REQUESTS` | Max requests per window | `100` |

## Frontend Setup

### Mobile App

```bash
cd frontend/mobile
flutter pub get
flutter run
```

### Website

```bash
cd frontend/website
flutter pub get
flutter run -d chrome
```

## Running Tests

```bash
cd backend
pytest tests/ -v
```

## Project Structure

```
axon/
├── backend/
│   ├── app/
│   │   ├── core/           # Database, auth, security, cache, gateway
│   │   ├── models/         # SQLAlchemy ORM models
│   │   ├── schemas/        # Pydantic request/response schemas
│   │   ├── services/       # Business logic by module
│   │   ├── storage/        # MinIO/local file storage
│   │   └── workers/        # Celery evaluation workers
│   ├── tests/              # Pytest test suite
│   └── requirements.txt
├── frontend/
│   ├── mobile/             # Flutter mobile app (field collection)
│   └── website/            # Flutter web app (dashboard, submission)
├── infra/                  # Infrastructure config (pending)
└── .github/prompts/docs/   # This documentation site
```
