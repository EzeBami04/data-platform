#!/usr/bin/env bash
# infrastructure/docker
#
# (Re)deploys the Airflow stack from the current state of the main branch.
# Idempotent — safe to run repeatedly, including from CI/CD.

set -euo pipefail

APP_DIR="${APP_DIR:-/airflow}"
COMPOSE_DIR="$APP_DIR"
COMPOSE_FILE="$COMPOSE_DIR/compose.yml"

cd "$APP_DIR"

echo "== 1. Pull latest code =="
git fetch origin
git reset --hard origin/main

echo "== 2. Verify environment file exists =="
if [ ! -f "$COMPOSE_DIR/.env" ]; then
  echo "ERROR: $COMPOSE_DIR/.env not found. Copy .env.example and fill in secrets." >&2
  exit 1
fi

echo "== 3. Build images =="
docker compose -f "$COMPOSE_FILE" --env-file "$COMPOSE_DIR/.env" build

echo "== 4. Run DB migration / admin-user init (idempotent) =="
docker compose -f "$COMPOSE_FILE" --env-file "$COMPOSE_DIR/.env" run --rm airflow-init

echo "== 5. Start/refresh services =="
docker compose -f "$COMPOSE_FILE" --env-file "$COMPOSE_DIR/.env" up -d --remove-orphans

echo "== 6. Clean up dangling images =="
docker image prune -f

echo "== 7. Health check =="
for i in $(seq 1 10); do
  if curl -fs http://localhost:8080/health >/dev/null; then
    echo "Airflow webserver is healthy."
    exit 0
  fi
  echo "Waiting for webserver to come up... ($i/10)"
  sleep 5
done

echo "WARNING: webserver did not report healthy within timeout." >&2
docker compose -f "$COMPOSE_FILE" logs --tail=100 airflow-webserver
exit 1