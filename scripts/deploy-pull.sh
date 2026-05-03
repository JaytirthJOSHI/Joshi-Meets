#!/usr/bin/env bash
# Run on the VPS after git pull: updates containers from GHCR and restarts the stack.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.small.yaml}"
ENV_FILE="${ENV_FILE:-.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy env.small.example and edit JOSHI_MEETS_IMAGE + MYSQL_ROOT_PASSWORD"
  exit 1
fi

git pull --ff-only

docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull joshi-meets-api
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

echo "Done. API image updated; stack is up."
