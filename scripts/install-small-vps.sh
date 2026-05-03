#!/usr/bin/env bash
# One-time prep on a small VPS after cloning this repo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Creating directories"
mkdir -p client/dist upload recording_files artifacts log etc/tmp/nats-data mariadb-data

if [[ ! -f nats_server.conf ]]; then
  echo "==> nats_server.conf from sample (edit NATS keys to match config.yaml)"
  cp -n nats_server_sample.conf nats_server.conf || true
fi

if [[ ! -f livekit.yaml ]]; then
  echo "==> livekit.yaml from sample (rotate keys before production)"
  cp -n livekit_sample.yaml livekit.yaml || true
fi

if [[ ! -f config.yaml ]]; then
  echo "==> config.yaml from sample — edit secrets, Redis/DB hosts, NATS URLs, LiveKit keys"
  cp -n config_sample.yaml config.yaml || true
fi

if [[ ! -f .env ]]; then
  echo "==> .env template — set passwords and Docker image name"
  cat <<'EOF' > .env
# Strong password for MariaDB root (required)
MYSQL_ROOT_PASSWORD=change-me-immediately

# GitHub Container Registry — same repo, lowercase (after first main build, set package to Public)
JOSHI_MEETS_IMAGE=ghcr.io/jaytirthjoshi/joshi-meets:dev
EOF
fi

echo ""
echo "Next steps:"
echo "  1. Edit .env (MYSQL_ROOT_PASSWORD, JOSHI_MEETS_IMAGE)"
echo "  2. Edit config.yaml — for 1GB VPS set shared_notepad.enabled: false (no Etherpad in small compose)"
echo "  3. Align livekit.yaml keys with config.yaml livekit_info"
echo "  4. Align nats_server.conf with config.yaml nats_info"
echo "  5. Put plugNmeet-client build output in client/dist/"
echo "  6. Add swap if needed: sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
echo "  7. docker compose -f docker-compose.small.yaml --env-file .env up -d"
echo "  Later updates: ./scripts/deploy-pull.sh"
echo ""
