# Backups and Restore

The stack includes a `db-backup` service that stores compressed PostgreSQL dumps and preview-file archives in the `backups` Docker volume.

Kitsu data is split across storage targets:

- PostgreSQL stores application records such as users, projects, tasks, comments, and metadata.
- The `previews` Docker volume stores uploaded/generated preview media from Zou at `PREVIEW_FOLDER` (`/opt/zou/previews` by default).
- The `zou_tmp` Docker volume stores temporary Zou runtime files at `TMP_DIR` (`/tmp/zou` by default). Treat this as runtime scratch data, not as a restore target.

A database dump alone is not a complete production restore once preview files exist. Restore both the database dump and the matching preview archive.

All commands below assume you are running from the repository root. Load both `.env` and `versions.env` because the Compose file uses deployment tags from `versions.env`.

## Automatic backups

The schedule is controlled by `.env`:

```env
BACKUP_CRON=30 1 * * *
BACKUP_RETENTION_DAYS=14
PREVIEW_BACKUP_RETENTION_DAYS=14
```

The default cron value runs every day at 01:30 UTC. Old `.sql.gz` files are deleted after `BACKUP_RETENTION_DAYS`; old `previews_*.tar.gz` files are deleted after `PREVIEW_BACKUP_RETENTION_DAYS`.

Each scheduled run creates:

- `<database>_<timestamp>.sql.gz` from PostgreSQL.
- `previews_<timestamp>.tar.gz` from the mounted `previews` volume.

## Manual full backup

Run this while the stack is up:

```bash
docker compose --env-file .env --env-file versions.env exec db-backup /backup_once.sh
```

On Windows Git Bash, disable MSYS path conversion so `/backup_once.sh` is passed to the container unchanged:

```bash
MSYS_NO_PATHCONV=1 docker compose --env-file .env --env-file versions.env exec db-backup /backup_once.sh
```

## Manual database-only backup

Run this when you only need a PostgreSQL dump:

```bash
docker compose --env-file .env --env-file versions.env exec db-backup /backup_db_once.sh
```

On Windows Git Bash:

```bash
MSYS_NO_PATHCONV=1 docker compose --env-file .env --env-file versions.env exec db-backup /backup_db_once.sh
```

## Manual preview-only backup

Run this when you only need a preview-file archive:

```bash
docker compose --env-file .env --env-file versions.env exec db-backup /backup_previews_once.sh
```

On Windows Git Bash:

```bash
MSYS_NO_PATHCONV=1 docker compose --env-file .env --env-file versions.env exec db-backup /backup_previews_once.sh
```

List the generated backups:

```bash
docker compose --env-file .env --env-file versions.env exec db-backup ls -lh /backups
```

For Windows Git Bash, use:

```bash
MSYS_NO_PATHCONV=1 docker compose --env-file .env --env-file versions.env exec db-backup ls -lh /backups
```

## Copy a backup to the host

First get the container name:

```bash
docker compose --env-file .env --env-file versions.env ps db-backup
```

Then copy the backup out:

```bash
docker cp <db-backup-container>:/backups/<backup-file>.sql.gz ./<backup-file>.sql.gz
docker cp <db-backup-container>:/backups/<preview-backup-file>.tar.gz ./<preview-backup-file>.tar.gz
```

## Restore warning

Restoring into an existing database can overwrite or conflict with current data. For real production data, test the restore on a separate copy of the stack before restoring over the active database.

## Restore into the running database

Stop application services first so they do not write while the restore is running:

```bash
docker compose --env-file .env --env-file versions.env stop zou-api zou-events zou-jobs zou-init-db kitsu-web nginx db-backup
```

Restore a compressed SQL dump:

```bash
gunzip -c <backup-file>.sql.gz | docker compose --env-file .env --env-file versions.env exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

Restore the matching preview archive into the `previews` volume:

```bash
docker run --rm -v kitsu_previews:/previews -v "$PWD:/restore:ro" alpine sh -c 'cd /previews && tar -xzf /restore/<preview-backup-file>.tar.gz'
```

On Windows Git Bash:

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v kitsu_previews:/previews -v "$PWD:/restore:ro" alpine sh -c 'cd /previews && tar -xzf /restore/<preview-backup-file>.tar.gz'
```

Start the services again:

```bash
docker compose --env-file .env --env-file versions.env up -d
```

## Safer restore test

The safer workflow is to restore into a fresh test stack or fresh Docker volume, verify login and project data, then decide whether to restore into the main stack.

Minimum checks after restore:

```bash
docker compose --env-file .env --env-file versions.env ps
curl -f http://localhost:${KITSU_WEB_HOST_PORT:-8080}/
curl -f http://localhost:${KITSU_WEB_HOST_PORT:-8080}/api
```
