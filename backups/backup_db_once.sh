#!/usr/bin/env bash
set -euo pipefail

stamp=$(date -u +%Y%m%d_%H%M%S)
output_path="/backups/${PGDATABASE}_${stamp}.sql.gz"
tmp_path="${output_path}.tmp"

cleanup_tmp_backup() {
  rm -f "${tmp_path}"
}

trap cleanup_tmp_backup EXIT
pg_dump -h "${PGHOST}" -U "${PGUSER}" "${PGDATABASE}" | gzip -9 >"${tmp_path}"
mv "${tmp_path}" "${output_path}"
trap - EXIT

echo "[backup] Created database dump ${output_path}"
find /backups -type f -name '*.sql.gz' -mtime +"${BACKUP_RETENTION_DAYS}" -delete -print
