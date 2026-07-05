#!/usr/bin/env sh
set -eu

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
ENV_FILE="${ENV_FILE:-.env}"
VERSION_ENV_FILE="${VERSION_ENV_FILE:-versions.env}"
HOST_PORT="${KITSU_WEB_HOST_PORT:-8080}"
HEALTH_TIMEOUT_SECONDS="${SMOKE_HEALTH_TIMEOUT_SECONDS:-180}"
CONFIG_ONLY="${CONFIG_ONLY:-0}"
RUN_BACKUP_SMOKE_TEST="${RUN_BACKUP_SMOKE_TEST:-0}"

fail() {
  echo "[smoke-test] ERROR: $*" >&2
  exit 1
}

compose() {
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" --env-file "$VERSION_ENV_FILE" "$@"
}

get_env_value() {
  key="$1"
  file="$2"
  [ -f "$file" ] || return 0
  awk -F= -v key="$key" '$1 == key {print $2; exit}' "$file" | tr -d '\r "'
}

service_defined() {
  compose config --services | grep -qx "$1"
}

require_running_service() {
  service="$1"
  if ! compose ps --services --status running | grep -qx "$service"; then
    fail "service is not running: $service"
  fi
}

wait_for_healthy_service() {
  service="$1"
  container_id="$(compose ps -q "$service")"
  [ -n "$container_id" ] || fail "service has no container: $service"

  elapsed=0
  while [ "$elapsed" -le "$HEALTH_TIMEOUT_SECONDS" ]; do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$container_id")"
    case "$status" in
      healthy)
        return 0
        ;;
      unhealthy)
        fail "service became unhealthy: $service"
        ;;
      missing)
        fail "service has no healthcheck: $service"
        ;;
    esac
    sleep 5
    elapsed=$((elapsed + 5))
  done

  fail "service did not become healthy within ${HEALTH_TIMEOUT_SECONDS}s: $service"
}

if [ ! -f "$ENV_FILE" ]; then
  fail "missing env file: $ENV_FILE"
fi

ENV_HOST_PORT="$(get_env_value KITSU_WEB_HOST_PORT "$ENV_FILE" || true)"
if [ -n "$ENV_HOST_PORT" ]; then
  HOST_PORT="$ENV_HOST_PORT"
fi

BASE_URL="${KITSU_BASE_URL:-http://localhost:${HOST_PORT}}"

echo "[smoke-test] Validating Compose file..."
compose config --quiet

if [ -f ".env.example" ]; then
  echo "[smoke-test] Validating Compose file with .env.example..."
  docker compose -f "$COMPOSE_FILE" --env-file .env.example --env-file "$VERSION_ENV_FILE" config --quiet
fi

echo "[smoke-test] Checking expected services in rendered Compose config..."
for service in db redis meilisearch zou-api zou-events zou-init-db zou-jobs kitsu-web nginx db-backup mailcatcher; do
  service_defined "$service" || fail "missing Compose service: $service"
done

if [ "$CONFIG_ONLY" = "1" ]; then
  echo "[smoke-test] CONFIG_ONLY=1; skipping runtime checks."
  echo "[smoke-test] OK"
  exit 0
fi

echo "[smoke-test] Checking running services..."
compose ps

for service in db redis meilisearch zou-api zou-events zou-jobs kitsu-web nginx db-backup; do
  require_running_service "$service"
done

echo "[smoke-test] Waiting for service healthchecks..."
for service in db redis meilisearch zou-api zou-events zou-jobs kitsu-web nginx; do
  wait_for_healthy_service "$service"
done

echo "[smoke-test] Checking zou-jobs service..."
require_running_service zou-jobs

echo "[smoke-test] Checking Meilisearch health from inside the container..."
compose exec -T meilisearch sh -c 'wget -qO- "http://127.0.0.1:${MEILI_PORT:-7700}/health" | grep -q available'

echo "[smoke-test] Checking preview and temp volume mounts..."
preview_folder="$(get_env_value PREVIEW_FOLDER "$ENV_FILE" || true)"
preview_folder="${preview_folder:-/opt/zou/previews}"
tmp_dir="$(get_env_value TMP_DIR "$ENV_FILE" || true)"
tmp_dir="${tmp_dir:-/tmp/zou}"
zou_api_container="$(compose ps -q zou-api)"
docker inspect --format '{{range .Mounts}}{{println .Name .Destination}}{{end}}' "$zou_api_container" | grep -F "kitsu_previews $preview_folder" >/dev/null \
  || fail "zou-api is missing the kitsu_previews mount at $preview_folder"
docker inspect --format '{{range .Mounts}}{{println .Name .Destination}}{{end}}' "$zou_api_container" | grep -F "kitsu_zou_tmp $tmp_dir" >/dev/null \
  || fail "zou-api is missing the kitsu_zou_tmp mount at $tmp_dir"
zou_jobs_container="$(compose ps -q zou-jobs)"
docker inspect --format '{{range .Mounts}}{{println .Name .Destination}}{{end}}' "$zou_jobs_container" | grep -F "kitsu_previews $preview_folder" >/dev/null \
  || fail "zou-jobs is missing the kitsu_previews mount at $preview_folder"
docker inspect --format '{{range .Mounts}}{{println .Name .Destination}}{{end}}' "$zou_jobs_container" | grep -F "kitsu_zou_tmp $tmp_dir" >/dev/null \
  || fail "zou-jobs is missing the kitsu_zou_tmp mount at $tmp_dir"

echo "[smoke-test] Checking Kitsu web at ${BASE_URL}/..."
curl -fsS --max-time 10 "${BASE_URL}/" >/dev/null

echo "[smoke-test] Checking Zou API through nginx at ${BASE_URL}/api..."
API_RESPONSE="$(curl -fsS --max-time 10 "${BASE_URL}/api")"
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$API_RESPONSE" | jq -e '.api == "Zou"' >/dev/null
else
  printf '%s' "$API_RESPONSE" | grep -Eq '"api"[[:space:]]*:[[:space:]]*"Zou"'
fi

echo "[smoke-test] Checking Socket.IO event route through nginx..."
EVENT_STATUS="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "${BASE_URL}/socket.io/?EIO=4&transport=polling" || true)"
case "$EVENT_STATUS" in
  2*|3*|4*)
    ;;
  *)
    fail "Socket.IO event route returned HTTP ${EVENT_STATUS:-000}"
    ;;
esac

if [ "$RUN_BACKUP_SMOKE_TEST" = "1" ]; then
  echo "[smoke-test] Running optional database backup check..."
  compose exec -T db-backup /backup_db_once.sh
fi

echo "[smoke-test] OK"
