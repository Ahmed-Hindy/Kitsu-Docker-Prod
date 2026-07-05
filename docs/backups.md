# Backups and Restore

The stack includes a `db-backup` service that stores compressed PostgreSQL dumps in the `backups` Docker volume.

All commands below assume you are running from the repository root. Load both `.env` and `versions.env` because the Compose file uses deployment tags from `versions.env`.

## Automatic backups

The schedule is controlled by `.env`:

```env
BACKUP_CRON=30 1 * * *
BACKUP_RETENTION_DAYS=14
```

The default cron value runs every day at 01:30 UTC. Old `.sql.gz` files are deleted after the configured retention period.

## Manual backup

Run this while the stack is up:

```bash
docker compose --env-file .env --env-file versions.env exec db-backup /backup_once.sh
```

On Windows Git Bash, disable MSYS path conversion so `/backup_once.sh` is passed to the container unchanged:

```bash
MSYS_NO_PATHCONV=1 docker compose --env-file .env --env-file versions.env exec db-backup /backup_once.sh
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
```

## Restore warning

Restoring into an existing database can overwrite or conflict with current data. For real production data, test the restore on a separate copy of the stack before restoring over the active database.

## Restore into the running database

Stop application services first so they do not write while the restore is running:

```bash
docker compose --env-file .env --env-file versions.env stop zou-api zou-events zou-init-db kitsu-web nginx
```

Restore a compressed SQL dump:

```bash
gunzip -c <backup-file>.sql.gz | docker compose --env-file .env --env-file versions.env exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
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
