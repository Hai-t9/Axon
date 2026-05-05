# Infrastructure & Deployment Configuration

## Overview
The `infra/` folder contains configuration files for running all backend services in containers using Docker Compose.

## Purpose

- ✅ Standardized environment setup
- ✅ Easy local development with all services
- ✅ Production-ready deployment
- ✅ Database, cache, storage all configured
- ✅ Reproducible across machines

## Components

```
infra/
├── nginx/
│   ├── .gitkeep
│   └── nginx.conf           # Reverse proxy configuration
│
├── minio/
│   ├── .gitkeep
│   └── init-buckets.sh      # Initialize S3 buckets
│
└── redis/
    ├── .gitkeep
    └── redis.conf           # Redis cache & broker config
```

## Services Overview

### **1. FastAPI** (Backend Server)
- Port: 8000
- Framework: FastAPI (Python)
- Database: PostgreSQL
- Routes: /api/register, /api/teams, etc.

### **2. PostgreSQL** (Database)
- Port: 5432
- Default DB: axon_db
- User: axon_user
- Persisted: `postgres_data/` volume

### **3. Redis** (Cache & Message Broker)
- Port: 6379
- Purpose: Celery queue, session caching
- Config: `infra/redis/redis.conf`

### **4. MinIO** (Object Storage)
- Port: 9000 (API)
- Port: 9001 (Web UI)
- Purpose: S3-compatible file storage
- Buckets: competitions, cache
- Persisted: `minio_data/` volume

### **5. Celery Worker** (Background Tasks)
- Consumes tasks from Redis queue
- Runs model evaluations
- Updates database with results

## Docker Compose Setup

Root-level `docker-compose.yml` orchestrates all services:

```yaml
version: '3.8'

services:
  # FastAPI Backend
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://axon_user:password@postgres:5432/axon_db
      REDIS_URL: redis://redis:6379/0
      MINIO_ENDPOINT: minio:9000
    depends_on:
      - postgres
      - redis
      - minio
    volumes:
      - ./backend/app:/app/app
    command: uvicorn app.main:app --host 0.0.0.0 --reload

  # PostgreSQL Database
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: axon_user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: axon_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  # Redis Cache & Broker
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - ./infra/redis/redis.conf:/usr/local/etc/redis/redis.conf
    command: redis-server /usr/local/etc/redis/redis.conf

  # MinIO Object Storage
  minio:
    image: minio/minio:latest
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data
      - ./infra/minio/init-buckets.sh:/init-buckets.sh
    command: server /data --console-address ":9001"

  # Celery Worker
  celery:
    build: ./backend
    command: celery -A app.workers.celery_app worker --loglevel=info
    environment:
      DATABASE_URL: postgresql://axon_user:password@postgres:5432/axon_db
      REDIS_URL: redis://redis:6379/0
    depends_on:
      - postgres
      - redis
    volumes:
      - ./backend/app:/app/app

volumes:
  postgres_data:
  minio_data:

networks:
  default:
    name: axon_network
```

---

## Individual Configurations

### **nginx/nginx.conf**
Reverse proxy for routing requests:

```nginx
server {
    listen 80;
    server_name localhost;

    # API routes
    location /api/ {
        proxy_pass http://backend:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Static files (if serving frontend)
    location / {
        root /usr/share/nginx/html;
        try_files $uri /index.html;
    }

    # MinIO console
    location /minio {
        proxy_pass http://minio:9001;
    }
}
```

**Used for:**
- ✅ Production deployment
- ✅ Route /api/* to FastAPI
- ✅ Serve static frontend files
- ✅ SSL termination in production

---

### **minio/init-buckets.sh**
Initialize MinIO buckets:

```bash
#!/bin/bash

# Wait for MinIO to start
sleep 10

# Configure MinIO credentials
export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD=minioadmin

# Create buckets
mc alias set minio http://minio:9000 minioadmin minioadmin

mc mb minio/competitions
mc mb minio/cache

echo "Buckets initialized"
```

**Buckets created:**
- `competitions` - Store competition images & models
- `cache` - Temporary files, thumbnails

---

### **redis/redis.conf**
Redis configuration:

```conf
# Memory management
maxmemory 512mb
maxmemory-policy allkeys-lru

# Persistence (RDB snapshots)
save 900 1
save 300 10
save 60 10000

# Logging
loglevel notice
logfile ""

# Default database
databases 16
```

**Key settings:**
- ✅ 512MB max memory
- ✅ LRU eviction when full
- ✅ Periodic snapshots
- ✅ 16 databases (0-15)

---

## Running Services Locally

### **Start All Services**
```bash
docker-compose up -d
```

Starts:
- FastAPI on http://localhost:8000
- PostgreSQL on localhost:5432
- Redis on localhost:6379
- MinIO on http://localhost:9000
- Celery worker in background

### **Check Status**
```bash
docker-compose ps
```

### **View Logs**
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f postgres
```

### **Stop Services**
```bash
docker-compose down
```

Removes containers, keeps volumes.

### **Clean Everything** (including data)
```bash
docker-compose down -v
```

---

## Database Management

### **Connect to PostgreSQL**
```bash
psql postgresql://axon_user:password@localhost:5432/axon_db
```

Or inside container:
```bash
docker-compose exec postgres psql -U axon_user -d axon_db
```

### **Create Database Tables**
```bash
docker-compose exec backend alembic upgrade head
```

### **Reset Database**
```bash
docker-compose down -v  # Remove volumes
docker-compose up       # Recreate empty
docker-compose exec backend alembic upgrade head
```

---

## MinIO Web UI

Access at http://localhost:9001

**Credentials:**
- Username: minioadmin
- Password: minioadmin

Can upload/download files manually for testing.

---

## Production Deployment

### **Differences from Local:**

| Aspect | Local | Production |
|--------|-------|-----------|
| **Docker** | docker-compose | Kubernetes / server |
| **Nginx** | Optional | Required (SSL, load balancing) |
| **Database** | Ephemeral (docker volume) | Managed database (RDS, Azure DB) |
| **Storage** | MinIO in container | Self-hosted MinIO or S3 |
| **Environment** | .env | Secrets manager |
| **Monitoring** | None | Prometheus, CloudWatch |

### **Production docker-compose.yml** additions:
```yaml
services:
  nginx:
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./infra/nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./ssl/certs:/etc/nginx/certs:ro

  # Add other services with production config...
```

---

## Environment Variables

Create `.env` file for local development:

```env
# Database
DATABASE_URL=postgresql://axon_user:password@postgres:5432/axon_db

# Redis
REDIS_URL=redis://redis:6379/0

# MinIO
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SECURE=false

# FastAPI
DEBUG=true
SECRET_KEY=dev-secret-key-change-in-production
```

---

## Troubleshooting

### **Port already in use**
```bash
# Change port in docker-compose.yml
ports:
  - "8001:8000"  # Use 8001 instead of 8000
```

### **Database connection refused**
```bash
# Wait for PostgreSQL to start
sleep 30 && docker-compose up
```

### **MinIO not initializing buckets**
```bash
# Check MinIO logs
docker-compose logs minio

# Manually create buckets
docker-compose exec minio mc alias set minio http://localhost:9000 minioadmin minioadmin
docker-compose exec minio mc mb minio/competitions
```

### **Celery tasks not running**
```bash
# Check Redis connection
docker-compose logs celery

# Check Redis is running
redis-cli -h localhost PING
```

---

## Adding New Services

To add a new service (e.g., message queue):

1. Add to `docker-compose.yml`:
```yaml
rabbitmq:
  image: rabbitmq:3.12
  ports:
    - "5672:5672"
  environment:
    RABBITMQ_DEFAULT_USER: user
    RABBITMQ_DEFAULT_PASS: password
```

2. Update depends_on in services that use it
3. Update environment variables
4. Document in this README

---

## CI/CD Integration

GitHub Actions can run tests in containers:

```yaml
# .github/workflows/test.yml
services:
  postgres:
    image: postgres:15
    env:
      POSTGRES_PASSWORD: password
  
  redis:
    image: redis:7

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      - postgres
      - redis
    steps:
      - run: pytest
```

---

## Monitoring & Health Checks

Add health checks to services:

```yaml
backend:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
    interval: 10s
    timeout: 3s
    retries: 3
```

---

Infrastructure = Deployment Configuration 🚀
