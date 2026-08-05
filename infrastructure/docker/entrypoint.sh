#!/usr/bin/env bash
# infrastructure/docker/entrypoint.sh
#
# Wraps the base apache/airflow image's own entrypoint to:
#   1. Fix ownership on host-mounted volumes (dags/logs/plugins can end up
#      root-owned when the host and container UIDs don't match)
#   2. Block until Postgres is actually accepting connections, so the
#      webserver/scheduler/triggerer don't crash-loop on cold start
#   3. Hand off to Airflow's real entrypoint with whatever command
#      docker-compose passed (webserver / scheduler / triggerer / bash -c ...)

set -euo pipefail

# Step 1 runs as root (container starts as root before Airflow's entrypoint drops privileges) /opt/airflow/plugins
if [ "$(id -u)" = "0" ]; then
  chown -R airflow: /opt/airflow/logs /opt/airflow/dags  2>/dev/null || true
  exec gosu airflow "$0" "$@"
fi

echo "Waiting for postgres..."
until pg_isready -h postgres -U "${POSTGRES_USER:-airflow}" >/dev/null 2>&1; do
  sleep 2
done
echo "Postgres is ready."

exec /entrypoint "$@"