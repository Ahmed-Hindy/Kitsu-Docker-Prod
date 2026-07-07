#!/usr/bin/env bash
set -euo pipefail

stamp=$(date -u +%Y%m%d_%H%M%S)
output_path="/backups/previews_${stamp}.tar.gz"
tmp_path="${output_path}.tmp"

cleanup_tmp_backup() {
  rm -f "${tmp_path}"
}

trap cleanup_tmp_backup EXIT
tar -C /previews -czf "${tmp_path}" .
mv "${tmp_path}" "${output_path}"
trap - EXIT

echo "[backup] Created preview archive ${output_path}"
find /backups -type f -name 'previews_*.tar.gz' -mtime +"${PREVIEW_BACKUP_RETENTION_DAYS}" -delete -print
