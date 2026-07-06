#!/usr/bin/env bash
set -euo pipefail

stamp=$(date -u +%Y%m%d_%H%M%S)
output_path="/backups/previews_${stamp}.tar.gz"

tar -C /previews -czf "${output_path}" .
echo "[backup] Created preview archive ${output_path}"
find /backups -type f -name 'previews_*.tar.gz' -mtime +"${PREVIEW_BACKUP_RETENTION_DAYS}" -delete -print
