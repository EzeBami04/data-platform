#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" = "0" ]; then
  chown -R airflow: /opt/airflow/logs /opt/airflow/dags 2>/dev/null || true
  exec gosu airflow "$0" "$@"
fi

if [[ "${AIRFLOW__DATABASE__SQL_ALCHEMY_CONN:-}" == postgresql* ]]; then
  echo "Waiting for postgres..."
  until pg_isready -h postgres -U "${POSTGRES_USER:-airflow}" >/dev/null 2>&1; do
    sleep 2
  done
  echo "Postgres is ready."
else
  echo "Non-Postgres backend detected, skipping wait."
fi

exec /entrypoint "$@"