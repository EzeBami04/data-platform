#!/usr/bin/env bash
# infrastructure/scripts/backup.sh
#
# Dumps the Airflow metadata DB and DAGs folder, uploads both to GCS,
# and prunes backups older than RETENTION_DAYS.
#
# Intended to run via cron on the VM, e.g.:
#   0 2 * * * GCS_BACKUP_BUCKET=gs://your-airflow-backups \
#     /opt/data-platform/infrastructure/scripts/backup.sh >> /var/log/airflow-backup.log 2>&1

set -euo pipefail

APP_DIR="${APP_DIR:-/airflow}"
COMPOSE_DIR="$APP_DIR/infrastructure/docker"
BUCKET="${GCS_BACKUP_BUCKET:?Set GCS_BACKUP_BUCKET, e.g. gs://your-airflow-backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
STAMP=$(date +%Y%m%d_%H%M%S)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$COMPOSE_DIR"

echo "== 1. Dump Postgres metadata DB =="
docker compose exec -T postgres pg_dump -U airflow airflow | gzip > "$TMP_DIR/airflow_db_${STAMP}.sql.gz"

echo "== 2. Archive DAGs folder =="
tar -czf "$TMP_DIR/dags_${STAMP}.tar.gz" -C "$APP_DIR/airflow" dags

echo "== 3. Upload to GCS =="
gsutil cp "$TMP_DIR/airflow_db_${STAMP}.sql.gz" "$BUCKET/db/"
gsutil cp "$TMP_DIR/dags_${STAMP}.tar.gz" "$BUCKET/dags/"

echo "== 4. Prune backups older than ${RETENTION_DAYS} days =="
CUTOFF=$(date -d "-${RETENTION_DAYS} days" +%Y%m%d)
gsutil ls "$BUCKET/db/" 2>/dev/null | while read -r f; do
  fname=$(basename "$f")
  fdate=$(echo "$fname" | grep -oE '[0-9]{8}' | head -1)
  if [ -n "$fdate" ] && [ "$fdate" -lt "$CUTOFF" ]; then
    gsutil rm "$f"
  fi
done

echo "Backup complete: airflow_db_${STAMP}.sql.gz, dags_${STAMP}.tar.gz"