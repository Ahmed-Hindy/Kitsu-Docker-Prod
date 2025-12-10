#!/usr/bin/env bash
set -eu

: "${BACKUP_CRON:?Need BACKUP_CRON env}"
: "${BACKUP_RETENTION_DAYS:=14}"

# Install cron, run a simple loop if cron isn't available in image
apt-get update >/dev/null 2>&1 || true
apt-get install -y --no-install-recommends cron >/dev/null 2>&1 || true

CRON_LINE="${BACKUP_CRON} /bin/bash -lc '/backup_once.sh >> /proc/1/fd/1 2>&1'"

cat >/backup_once.sh <<'EOS'
#!/usr/bin/env bash
set -eu
STAMP=$(date -u +%Y%m%d_%H%M%S)
OUT="/backups/${PGDATABASE}_${STAMP}.sql.gz"
pg_dump -h "${PGHOST}" -U "${PGUSER}" "${PGDATABASE}" | gzip -9 > "${OUT}"
echo "[backup] Created ${OUT}"
# Retention
find /backups -type f -name '*.sql.gz' -mtime +${BACKUP_RETENTION_DAYS} -delete -print
EOS
chmod +x /backup_once.sh

# Register cron job
crontab -l 2>/dev/null | { cat; echo "${CRON_LINE}"; } | crontab -

# Start cron in foreground
cron -f
