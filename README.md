# Quantum B Data Platform

This repository provides a self-hosted Apache Airflow deployment on a Google Compute Engine VM with an attached dbt project for transformation.

Key components:
- Dockerized Apache Airflow 3.2.0 with LocalExecutor
- PostgreSQL metadata database inside Docker Compose
- Airflow DAGs and Python ingestion code mounted from the repo
- Included dbt project mounted into the Airflow container for transformation
- Nginx + Certbot bootstrap script for exposing Airflow securely through a subdomain
- GitHub Actions deployment workflow to deploy to a GCE VM

## Recommended VM layout

The VM should host the repository at /airflow and run Docker Compose from /airflow/infrastructure/docker.

## Setup a fresh VM

On a fresh Debian/Ubuntu VM, run:

`ash
DOMAIN_NAME=orch.quantumbdata.org \
CERTBOT_EMAIL=you@example.com \
REPO_URL=git@github.com:Ezebami04/data-platform.git \
bash /airflow/infrastructure/scripts/install.sh
`

Then copy the Docker environment file and update the secret values:

`ash
cp /airflow/infrastructure/docker/.env.example /airflow/infrastructure/docker/.env
# edit /airflow/infrastructure/docker/.env
`

## Deploy Airflow stack

Run the deploy script from the VM:

`ash
bash /airflow/infrastructure/scripts/deploy.sh
`

The deploy script will:
- fetch the latest main branch from Git
- build the Airflow Docker image
- initialize the Airflow metadata database and admin user
- start the Airflow webserver, scheduler, and triggerer
- verify the webserver health

## Accessing Airflow

After a successful install and deploy, your Airflow UI will be available at:

https://replace_with_your_targeted_subdomain

## dbt integration

The dbt project is located at /airflow/sql/qntplatform and is mounted into the Airflow container at /opt/airflow/dbt.

The sample DAG irflow/dags/fstdag.py runs:
- dbt deps
- dbt run
- dbt test

Update sql/qntplatform/profiles.yml with your BigQuery project, dataset, and service account key path.

## GitHub deployment

The GitHub workflow in .github/workflows/deploy.yml SSHs into the VM and runs the deploy script.

Required secrets:
- GCP_SA_KEY
- GCP_PROJECT_ID
- GCP_ZONE
- GCP_VM_NAME

