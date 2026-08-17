#!/usr/bin/env bash
# infrastructure/scripts/deploy.sh
#
# Pulls the pre-built Airflow image from Docker Hub and (re)starts the stack.
# Idempotent — safe to run repeatedly, including from CI/CD.

set -euo pipefail

APP_DIR="${APP_DIR:-/home/analystbami30/airflow}"
COMPOSE_DIR="$APP_DIR"
COMPOSE_FILE="$COMPOSE_DIR/compose.yml"
ENV_FILE="$COMPOSE_DIR/.env"

cd "$APP_DIR"

echo "== 0. Verify environment file exists =="
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found." >&2
  exit 1
fi

# Load .env into this shell so DOCKERHUB_USERNAME/DOCKERHUB_TOKEN
# are available to plain shell commands (docker login), not just
# to `docker compose --env-file`, which parses the file separately.
set -a
source "$ENV_FILE"
set +a

echo "== 1. Log in to Docker Hub =="
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

echo "== 2. Pull latest image =="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull

echo "== 3. Run DB migration / admin-user init (idempotent) =="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" run --rm airflow-init

echo "== 4. Start/refresh services =="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --remove-orphans

echo "== 5. Clean up dangling images =="
docker image prune -f

echo "== 6. Health check =="
for i in $(seq 1 10); do
  if curl -fs http://localhost:8080/health >/dev/null; then
    echo "Airflow webserver is healthy."
    exit 0
  fi
  echo "Waiting for webserver to come up... ($i/10)"
  sleep 5
done

echo "WARNING: webserver did not report healthy within timeout." >&2
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs --tail=100 airflow-api-server
exit 1