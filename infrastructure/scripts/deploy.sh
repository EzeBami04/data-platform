echo "== 1. Log in to Docker Hub =="
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

echo "== 2. Pull latest image =="
docker compose -f "$COMPOSE_FILE" --env-file "$COMPOSE_DIR/.env" pull

echo "== 3. Run DB migration / admin-user init =="
docker compose -f "$COMPOSE_FILE" --env-file "$COMPOSE_DIR/.env" run --rm airflow-init

echo "== 4. Start/refresh services =="
docker compose -f "$COMPOSE_FILE" --env-file "$COMPOSE_DIR/.env" up -d --remove-orphans