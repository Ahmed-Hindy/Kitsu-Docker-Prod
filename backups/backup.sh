#!/usr/bin/env bash
set -euo pipefail

: "${BACKUP_CRON:?Need BACKUP_CRON env}"
: "${BACKUP_RETENTION_DAYS:=14}"
: "${PGDATABASE:?Need PGDATABASE env}"
: "${PGHOST:?Need PGHOST env}"
: "${PGPASSWORD:?Need PGPASSWORD env}"
: "${PGUSER:?Need PGUSER env}"
: "${PREVIEW_BACKUP_RETENTION_DAYS:=14}"

write_env() {
  local name="$1"
  printf 'export %s=%q\n' "${name}" "${!name}"
}

cat >/backup_db_once.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
STAMP=$(date -u +%Y%m%d_%H%M%S)
OUT="/backups/${PGDATABASE}_${STAMP}.sql.gz"
pg_dump -h "${PGHOST}" -U "${PGUSER}" "${PGDATABASE}" | gzip -9 > "${OUT}"
echo "[backup] Created database dump ${OUT}"
find /backups -type f -name '*.sql.gz' -mtime +"${BACKUP_RETENTION_DAYS}" -delete -print
EOS
chmod +x /backup_db_once.sh

cat >/backup_previews_once.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
STAMP=$(date -u +%Y%m%d_%H%M%S)
OUT="/backups/previews_${STAMP}.tar.gz"
tar -C /previews -czf "${OUT}" .
echo "[backup] Created preview archive ${OUT}"
find /backups -type f -name 'previews_*.tar.gz' -mtime +"${PREVIEW_BACKUP_RETENTION_DAYS}" -delete -print
EOS
chmod +x /backup_previews_once.sh

cat >/backup_once.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
/backup_db_once.sh
/backup_previews_once.sh
EOS
chmod +x /backup_once.sh

{
  write_env PGDATABASE
  write_env PGHOST
  write_env PGPASSWORD
  write_env PGUSER
  write_env BACKUP_RETENTION_DAYS
  write_env PREVIEW_BACKUP_RETENTION_DAYS
} >/run/backup.env
chmod 0600 /run/backup.env

CRONTAB=/run/backup.cron
printf "%s /bin/bash -lc '. /run/backup.env; /backup_once.sh'\n" "${BACKUP_CRON}" >"${CRONTAB}"

exec supercronic "${CRONTAB}"
