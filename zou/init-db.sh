#!/bin/sh
set -eu

log() {
  printf '[zou-init-db] %s\n' "$*"
}

PYTHON=/opt/venv/bin/python
ZOU=/opt/venv/bin/zou

require_env() {
  name="$1"
  eval "value=\${$name:-}"
  if [ -z "$value" ]; then
    log "Missing required environment variable: $name"
    exit 1
  fi
}

require_env DB_HOST
require_env DB_PORT
require_env DB_USERNAME
require_env DB_PASSWORD
require_env DB_DATABASE
require_env ZOU_ADMIN_EMAIL
require_env ZOU_ADMIN_PASSWORD

log "Checking database state..."
db_state="$("$PYTHON" - <<'PY'
import os
import sys

import psycopg2

try:
    conn = psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        user=os.environ["DB_USERNAME"],
        password=os.environ["DB_PASSWORD"],
        dbname=os.environ["DB_DATABASE"],
        connect_timeout=10,
    )
except Exception as exc:
    print(f"ERROR: cannot connect to Postgres: {exc}", file=sys.stderr)
    sys.exit(2)

with conn:
    with conn.cursor() as cur:
        cur.execute("SELECT to_regclass('public.alembic_version') IS NOT NULL")
        has_alembic = cur.fetchone()[0]
        cur.execute(
            """
            SELECT count(*)
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_type = 'BASE TABLE'
            """
        )
        table_count = cur.fetchone()[0]

conn.close()

if has_alembic:
    print("initialized")
elif table_count == 0:
    print("empty")
else:
    print("partial")
PY
)"

case "$db_state" in
  empty)
    first_init=1
    log "Database is empty; running zou init-db."
    "$ZOU" init-db
    ;;
  initialized)
    first_init=0
    log "Database schema already exists; applying migrations."
    "$ZOU" upgrade-db --no-telemetry
    ;;
  partial)
    log "Database has tables but no alembic_version marker. Refusing to guess; inspect the database before rerunning."
    exit 1
    ;;
  *)
    log "Unexpected database state: $db_state"
    exit 1
    ;;
esac

log "Ensuring required Zou seed data exists..."
"$ZOU" init-data

if [ "$first_init" -eq 1 ]; then
  log "Resetting search index after first database initialization..."
  "$ZOU" reset-search-index
else
  log "Skipping search index reset for an already initialized database."
fi

admin_state="$("$PYTHON" - <<'PY'
import os
import sys

import psycopg2

try:
    conn = psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        user=os.environ["DB_USERNAME"],
        password=os.environ["DB_PASSWORD"],
        dbname=os.environ["DB_DATABASE"],
        connect_timeout=10,
    )
except Exception as exc:
    print(f"ERROR: cannot connect to Postgres: {exc}", file=sys.stderr)
    sys.exit(2)

with conn:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT role FROM person WHERE lower(email) = lower(%s) AND is_bot IS NOT TRUE LIMIT 1",
            (os.environ["ZOU_ADMIN_EMAIL"],),
        )
        row = cur.fetchone()
        if row is None:
            print("missing")
        elif row[0] == "admin":
            print("admin")
        else:
            print("non_admin")

conn.close()
PY
)"

case "$admin_state" in
  admin)
    log "Admin email already exists with admin role; leaving the existing account unchanged."
    ;;
  missing)
    log "Creating initial admin account..."
    "$ZOU" create-admin "$ZOU_ADMIN_EMAIL" --password "$ZOU_ADMIN_PASSWORD"
    ;;
  non_admin)
    log "Admin email exists without admin role; promoting it through zou create-admin."
    "$ZOU" create-admin "$ZOU_ADMIN_EMAIL" --password "$ZOU_ADMIN_PASSWORD"
    ;;
  *)
    log "Unexpected admin lookup result: $admin_state"
    exit 1
    ;;
esac

log "Done."
