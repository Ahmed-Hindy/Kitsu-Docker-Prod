#!/bin/bash
set -e

echo "[entrypoint] Waiting for PostgreSQL at ${DATABASE_URL:-postgres://...}"

# Optional: wait for DB to be reachable
python - << 'PY'
import os, time
import psycopg

db_url = os.environ.get("DATABASE_URL")
if not db_url:
    raise SystemExit("DATABASE_URL is not set")

for i in range(30):
    try:
        with psycopg.connect(db_url, connect_timeout=3):
            print("[entrypoint] Database is up.")
            break
    except Exception as e:
        print(f"[entrypoint] DB not ready yet ({e}), retrying...")
        time.sleep(2)
else:
    raise SystemExit("[entrypoint] Database not reachable, giving up.")
PY

echo "[entrypoint] Running zou init-db (safe if already applied)..."
zou init-db || echo "[entrypoint] zou init-db failed (maybe already applied?)"

echo "[entrypoint] Running zou init-data (idempotent)..."
zou init-data || echo "[entrypoint] zou init-data failed (maybe already initialized?)"

# Auto-create admin if it doesn't exist yet
if [[ -n "$ZOU_ADMIN_EMAIL" && -n "$ZOU_ADMIN_PASSWORD" ]]; then
  echo "[entrypoint] Ensuring admin user exists: $ZOU_ADMIN_EMAIL"
  zou create-admin --password "$ZOU_ADMIN_PASSWORD" "$ZOU_ADMIN_EMAIL" || \
    echo "[entrypoint] create-admin failed (probably already exists, ignoring)."
else
  echo "[entrypoint] ZOU_ADMIN_EMAIL or ZOU_ADMIN_PASSWORD not set, skipping admin creation."
fi

echo "[entrypoint] Starting gunicorn..."
exec gunicorn -c gunicorn.conf.py "zou.app:app"
# CMD ["gunicorn", "-c", "gunicorn.conf.py", "zou.app:app"]
