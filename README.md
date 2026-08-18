# Quantum B Data Platform

This repository provisions a self-hosted Apache Airflow 3.x deployment on a Google Compute Engine VM, with an attached dbt project for BigQuery transformations. Airflow images are built and published to Docker Hub by CI, then pulled and run on the VM — the VM never builds images locally.

Live instance: `orch.quantumbdata.org`

## Key components

- Dockerized Apache Airflow 3.2 with LocalExecutor
- PostgreSQL metadata database inside Docker Compose
- Airflow DAGs and Python ingestion code mounted from the repo
- dbt project mounted into the Airflow container for transformation against BigQuery
- Nginx + Certbot bootstrap for exposing Airflow securely through a subdomain
- GitHub Actions CI/CD: build & push to Docker Hub, then deploy to the VM
- Shared VM: this stack coexists with a separate live n8n stack on the same host — see [Shared VM caution](#shared-vm-caution)

## Architecture: image flow

```
GitHub push to main
      │
      ▼
GitHub Actions (deploy.yml)
      │
      ├─ 1. Build image ─────────► Docker Hub (analystbami/airflow-dbt-app)
      │                              tagged :latest and :<github.sha>
      │
      ├─ 2. SCP compose.yml + deploy.sh ──► VM (/home/analystbami30/airflow)
      │
      └─ 3. SSH into VM ──► run deploy.sh
                               │
                               ├─ docker login (Docker Hub)
                               ├─ docker compose pull
                               ├─ airflow-init (db migrate + admin user)
                               └─ docker compose up -d
```

The repository is always the source of truth. `compose.yml` and `deploy.sh` are overwritten on the VM on every deploy — **never hand-edit files directly on the VM**, changes will be lost on the next push to `main`.

## Recommended VM layout

The VM (`n8ndev`) hosts this repo at `/home/analystbami30/airflow` and runs Docker Compose from that directory. A separate, unrelated n8n stack (five containers) runs elsewhere on the same VM — see the caution note below before running any daemon-wide Docker commands.

## Prerequisites

- A GCE VM (Debian/Ubuntu) with Docker, Docker Compose plugin, nginx, and certbot installed (`install.sh` handles this on a fresh VM)
- A Docker Hub account/repository to publish images to (`analystbami/airflow-dbt-app` in this project)
- A BigQuery project and a service account key with permissions for your target dataset

## Setup a fresh VM

```bash
DOMAIN_NAME=your_subdomain_attached_to_the_ui \
CERTBOT_EMAIL=you@example.com \
REPO_URL=git@github.com:Ezebami04/data-platform.git \
bash /airflow/infrastructure/scripts/install.sh
```

This installs Docker, the Compose plugin, nginx, and certbot, clones the repo, and issues a TLS certificate for the given subdomain.

Then copy the Docker environment file and fill in real secrets:

```bash
cp /airflow/infrastructure/docker/.env.example /airflow/infrastructure/docker/.env
# edit /airflow/infrastructure/docker/.env
```

Required values in `.env`:

| Variable | Notes |
|---|---|
| `AIRFLOW_IMAGE` | Full Docker Hub image reference, e.g. `analystbami/airflow-dbt-app:latest` (or a specific `:<sha>` for rollback) |
| `FERNET_KEY` | Must be a properly generated, base64-encoded 32-byte key — generate with `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` |
| `SECRET_KEY` | Any random secret string for the webserver |
| `EMAIL` / `ADMIN_PASSWORD` | Used by `airflow-init` to create the initial admin user |

> **Airflow 3.x note:** the FAB auth manager is no longer implicit. `compose.yml`'s `x-airflow-common` environment block must explicitly set:
> ```
> AIRFLOW__CORE__AUTH_MANAGER: airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager
> ```
> Omitting this causes `AttributeError: 'AirflowSecurityManagerV2' object has no attribute 'find_role'` during admin user creation in `airflow-init`.

## Deploying

Deploys are triggered automatically on every push to `main` via `.github/workflows/deploy.yml`, or manually via `workflow_dispatch`. The workflow:

1. Builds the image and pushes it to Docker Hub, tagged `:latest` and `:<github.sha>`
2. SCPs the current `compose.yml` and `deploy.sh` from the repo to the VM
3. SSHs into the VM and runs `deploy.sh`, which pulls the new image and rolls out the stack

To deploy manually from the VM instead:

```bash
bash /home/analystbami30/airflow/deploy.sh
```

`deploy.sh` is idempotent — safe to re-run. It sources `.env`, logs in to Docker Hub, pulls the image, runs `airflow-init`, brings the stack up, and health-checks `airflow-api-server` before exiting.

### Rolling back

Because every image is also tagged with its `github.sha`, you can roll back by pointing `AIRFLOW_IMAGE` in `.env` at a previous SHA tag and re-running `deploy.sh`.

## Accessing Airflow

After a successful install and deploy, the Airflow UI is available at:

`https://orch.quantumbdata.org`

## dbt integration

The dbt project lives at `/airflow/sql/qntplatform` and is mounted into the Airflow container at `/opt/airflow/dbt`.

The sample DAG `airflow/dags/fstdag.py` runs, in order:
- `dbt deps`
- `dbt run`
- `dbt test`

Update `sql/qntplatform/profiles.yml` with your BigQuery project, dataset, and service account key path before running the DAG.

## GitHub Actions

| Workflow | Trigger | Purpose |
|---|---|---|
| `lint.yml` | Pull requests to `main` | Static checks only (Python, SQL, YAML) — no build |
| `ci.yml` | Push/PR to `main` | Builds the Airflow image and validates every DAG imports cleanly |
| `deploy.yml` | Push to `main`, or manual dispatch | Builds & pushes the image to Docker Hub, then deploys to the VM |

### Required GitHub secrets

**Docker Hub (build & push):**
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

**GCP (VM access for deployment):**
- `GCP_SA_KEY`
- `GCP_PROJECT_ID`
- `GCP_ZONE`
- `GCP_VM_NAME`

## Shared VM caution

This VM also runs a separate, live n8n stack (five containers) in its own directory. Any **daemon-wide** Docker command — `docker image prune -a`, `docker builder prune`, `docker system prune`, etc. — affects both stacks simultaneously. Prefer scoping cleanup to this project's Compose files where possible, and coordinate before running daemon-wide commands.

## Known gaps / on the roadmap

- **Nginx config** (`infrastructure/nginx/airflow.conf`) currently lives only on the VM filesystem and is not synced by `deploy.yml`. Changes made there today will not survive a manual VM rebuild — bringing it under version control and automated deployment is planned.
- **Resource limits**: `compose.yml` does not yet set `mem_limit` / `cpus` per service, or pin an explicit Compose `name: airflow` project name, both of which help this stack coexist safely with n8n on the shared VM.

## Repository layout

```
.
├── .github/workflows/        # lint.yml, ci.yml, deploy.yml
├── airflow/dags/              # DAG definitions
├── infrastructure/
│   ├── docker/                # Dockerfile, compose.yml, entrypoint.sh, .env.example
│   ├── nginx/                 # airflow.conf (reverse proxy template)
│   └── scripts/                # install.sh, deploy.sh, backup.sh
├── python/                     # ingestion/loader/shared modules, mounted into the image
├── sql/qntplatform/            # dbt project (models, seeds, macros, tests, profiles.yml)
└── requirements.txt
```