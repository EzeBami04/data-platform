#!/usr/bin/env bash
set -euo pipefail
APP_DIR="/home/analystbami30/airflow"
COMPOSE_DIR="$APP_DIR"
COMPOSE_FILE="$COMPOSE_DIR/compose.yml"
ENV_FILE="$COMPOSE_DIR/.env"
cd "$COMPOSE_DIR"

echo "== Checking Compose configuration =="
[ -f "$COMPOSE_FILE" ] || { echo "ERROR: $COMPOSE_FILE not found"; exit 1; }
[ -f "$ENV_FILE" ] || { echo "ERROR: $ENV_FILE not found"; exit 1; }

echo "== Pulling latest Airflow image =="
attempt=1
max_attempts=5
until docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull; do
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "ERROR: image pull failed after $max_attempts attempts" >&2
    exit 1
  fi
  wait_time=$((attempt * 10))
  echo "Pull attempt $attempt failed, retrying in ${wait_time}s..."
  sleep "$wait_time"
  attempt=$((attempt + 1))
done

echo "== Starting Airflow =="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --remove-orphans

echo "== Container status =="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
echo "== Deployment complete =="