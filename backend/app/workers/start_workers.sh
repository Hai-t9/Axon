#!/usr/bin/env bash
# Start Celery workers for model evaluation.
#
# GPU mode (EVAL_GPU_ENABLE=true in .env):
#   Starts one worker per GPU, each pinned to a different device via
#   CUDA_VISIBLE_DEVICES.  Workers run with --concurrency=1 so one
#   evaluation container gets the full GPU.
#
# CPU mode (default):
#   Starts a single worker that uses all available CPU cores.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$APP_DIR"

# shellcheck disable=SC2046
export $(grep -v '^#' "$APP_DIR/.env" | xargs)

if [ "${EVAL_GPU_ENABLE:-false}" = "true" ]; then
    GPU_COUNT="${EVAL_GPU_COUNT:-1}"
    echo "Starting $GPU_COUNT GPU workers (one per device)..."

    for ((i = 0; i < GPU_COUNT; i++)); do
        export CUDA_VISIBLE_DEVICES=$i
        echo "  Worker $i → CUDA_VISIBLE_DEVICES=$i"
        celery -A app.workers.celery_app worker \
            --concurrency=1 \
            --hostname="gpu${i}" \
            --loglevel=info &
    done
else
    echo "Starting CPU worker..."
    celery -A app.workers.celery_app worker \
        --loglevel=info &
fi

echo "Workers started.  Use 'jobs' and 'kill %%' to stop."
wait
