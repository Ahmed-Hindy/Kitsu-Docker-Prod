#!/usr/bin/env bash
set -euo pipefail

stamp=$(date -u +%Y%m%d_%H%M%S)
output_path="/backups/${PGDATABASE}_${stamp}.sql.gz"

pg_dump -h "${PGHOST}" -U "${PGUSER}" "${PGDATABASE}" | gzip -9 >"${output_path}"
echo "[backup] Created database dump ${output_path}"
find /backups -type f -name '*.sql.gz' -mtime +"${BACKUP_RETENTION_DAYS}" -delete -print
