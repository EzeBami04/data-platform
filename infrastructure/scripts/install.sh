#!/usr/bin/env bash
# infrastructure/scripts/install.sh
#
# One-time bootstrap for a fresh GCP Compute Engine VM (Debian/Ubuntu image).
# Installs Docker, nginx, certbot, clones the repo, and issues a TLS cert.
#
# Usage:
#   DOMAIN_NAME=airflow.example.com CERTBOT_EMAIL=you@example.com \
#     REPO_URL=git@github.com:your-org/data-platform.git \
#     bash install.sh

set -euo pipefail

REPO_URL="${REPO_URL:-git@github.com:your-org/data-platform.git}"
APP_DIR="${APP_DIR:-/opt/data-platform}"
DOMAIN_NAME="${DOMAIN_NAME:?Set DOMAIN_NAME, e.g. DOMAIN_NAME=airflow.example.com}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:?Set CERTBOT_EMAIL, e.g. CERTBOT_EMAIL=you@example.com}"

echo "== 1. System update =="
sudo apt-get update -y && sudo apt-get upgrade -y

echo "== 2. Install Docker Engine =="
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
fi

echo "== 3. Install Docker Compose plugin =="
sudo apt-get install -y docker-compose-plugin

echo "== 4. Install nginx + certbot =="
sudo apt-get install -y nginx certbot python3-certbot-nginx

echo "== 5. Configure firewall (ufw) =="
sudo apt-get install -y ufw
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo "== 6. Clone repository =="
if [ ! -d "$APP_DIR" ]; then
  sudo git clone "$REPO_URL" "$APP_DIR"
  sudo chown -R "$USER":"$USER" "$APP_DIR"
else
  echo "$APP_DIR already exists, skipping clone."
fi

echo "== 7. Prepare host directories (must be owned by Airflow's UID 50000) =="
mkdir -p "$APP_DIR"/airflow/{dags,logs,plugins}
sudo chown -R 50000:0 "$APP_DIR"/airflow

echo "== 8. Install nginx site config (HTTP only — cert added next step) =="
sudo cp "$APP_DIR/infrastructure/nginx/airflow.conf" /etc/nginx/sites-available/airflow.conf
sudo sed -i "s/__DOMAIN_NAME__/${DOMAIN_NAME}/g" /etc/nginx/sites-available/airflow.conf
sudo ln -sf /etc/nginx/sites-available/airflow.conf /etc/nginx/sites-enabled/airflow.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx

echo "== 9. Issue TLS certificate and enable HTTPS redirect =="
sudo certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos -m "$CERTBOT_EMAIL" --redirect

echo "== 10. Enable certbot auto-renewal timer =="
sudo systemctl enable --now certbot.timer

cat <<EOF

Bootstrap complete.
Next steps:
  1. Log out and back in so the 'docker' group membership takes effect.
  2. cp $APP_DIR/infrastructure/docker/.env.example $APP_DIR/infrastructure/docker/.env
     and fill in real secrets.
  3. Run: bash $APP_DIR/infrastructure/scripts/deploy.sh
EOF