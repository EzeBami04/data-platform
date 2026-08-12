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
for i in 1 2 3; do
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull && break
  echo "Pull attempt $i failed, retrying..."; sleep 5
done

echo "== Starting Airflow =="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --remove-orphans

echo "== Container status =="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
echo "== Deployment complete =="