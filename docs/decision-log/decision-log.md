---
sidebar_position: 1
---

# Decision Log

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Backend framework | FastAPI (Python) | Built-in async, auto-docs, ML ecosystem compatibility |
| Database | PostgreSQL (Supabase) | ACID compliance, JSON support, free hosted tier |
| ORM | SQLAlchemy | Mature Python ORM, Alembic migrations |
| Auth | Custom JWT (HMAC-SHA256) | No external dependency, full control, simple for students |
| Password hashing | PBKDF2-SHA256 | Built-in hashlib, no extra deps, NIST-recommended |
| Task queue | Celery + Redis | Standard Python task queue, easy scaling |
| Model execution | Docker containers | Isolation, reproducibility, multi-framework support |
| Object storage | MinIO (S3 via boto3) + local fallback | Self-hosted, S3-compatible, zero egress costs |
| Frontend | Flutter/Dart (separate mobile + web) | Cross-platform UI toolkit |
| Phase management | Single PhaseLog table with JSON | Simple, no schema changes for new phase features |

## Technical Choices

| Choice | Implementation |
|---|---|
| ID types | UUID for core entities, Integer for detail tables (image, label, etc.) |
| Team membership | JSON `user_emails` dict (`{"email": 0|1}`) — no separate members table |
| Phase data | All phase state (timeline, deadlines, history, mode) in one JSON column |
| Config table | UUID PK (not auto-increment integer), 1:1 with competition |
| Framework auto-detection | File extension analysis in Docker submission zip |
| Hash deduplication | SHA-256, enforced at application level (not DB unique constraint) |
| Validation threshold | Max votes per image from config, auto-finalize on threshold reached |
| Assignment strategy | Round-robin distribution across teams, stored in Redis |

## Pending Decisions

| Topic | Status |
|---|---|
| Docker Compose for local dev | Not implemented — services run natively |
| GitHub Actions CI/CD | Not implemented |
| Separate Data Ingestion service | Replaced by Image module |
| Separate Data Validation service | Replaced by Validation module |
| Full Cleaner pipeline | Skeleton/mock only |
