#!/usr/bin/env sh
set -eu

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
ENV_FILE="${ENV_FILE:-.env}"
VERSION_ENV_FILE="${VERSION_ENV_FILE:-versions.env}"
HOST_PORT="${KITSU_WEB_HOST_PORT:-8080}"

if [ -f "$ENV_FILE" ]; then
  ENV_HOST_PORT=$(awk -F= '/^KITSU_WEB_HOST_PORT=/ {print $2; exit}' "$ENV_FILE" | tr -d ' "' || true)
  if [ -n "$ENV_HOST_PORT" ]; then
    HOST_PORT="$ENV_HOST_PORT"
  fi
fi

BASE_URL="${KITSU_BASE_URL:-http://localhost:${HOST_PORT}}"

echo "[smoke-test] Validating Compose file..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" --env-file "$VERSION_ENV_FILE" config --quiet

if [ -f ".env.example" ]; then
  echo "[smoke-test] Validating Compose file with .env.example..."
  docker compose -f "$COMPOSE_FILE" --env-file .env.example --env-file "$VERSION_ENV_FILE" config --quiet
fi

echo "[smoke-test] Checking running services..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" --env-file "$VERSION_ENV_FILE" ps

echo "[smoke-test] Checking Kitsu web at ${BASE_URL}/..."
curl -fsS "${BASE_URL}/" >/dev/null

echo "[smoke-test] Checking Zou API through nginx at ${BASE_URL}/api..."
curl -fsS "${BASE_URL}/api" | grep '"api":"Zou"' >/dev/null

echo "[smoke-test] OK"
