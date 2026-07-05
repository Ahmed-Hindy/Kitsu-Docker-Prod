# Postgres Upgrade Runbook

This runbook is for a future Postgres major-version upgrade. Do not use it for normal Kitsu or Zou application updates.

The current stack keeps Postgres pinned in `versions.env` and stores data in the `kitsu_pgdata` named volume. A major-version change is not just an image tag change; the database files must be migrated or restored into a compatible data directory.

## Goals

- Preserve the existing Kitsu/Zou database.
- Keep a tested rollback path.
- Avoid changing app images and database major versions in the same PR.
- Validate the migration on copied data before touching the real production volume.

## Before You Start

1. Confirm the target Postgres version is supported by the current Zou version.
2. Confirm the stack is healthy before the upgrade.
3. Run a fresh manual backup.
4. Copy the backup off the Docker volume to host storage.
5. Test restore on a disposable stack or copied volume.

Useful checks:

```bash
docker compose --env-file .env --env-file versions.env ps
docker compose --env-file .env --env-file versions.env exec db-backup /backup_once.sh
docker compose --env-file .env --env-file versions.env exec db-backup ls -lh /backups
```

## Recommended Migration Strategy

Prefer dump/restore over in-place mutation for this repository until an automated upgrade helper has been implemented and tested.

High-level flow:

1. Stop application services that write to the database.
2. Keep or start the old Postgres service long enough to create a final dump.
3. Create a new Postgres data volume using the target version.
4. Restore the dump into the new Postgres instance.
5. Start Zou against the new database.
6. Run the smoke test.
7. Keep the old volume untouched until the upgraded stack is accepted.

Do not delete the old Postgres volume during the same maintenance window.

## Validation

After restoring into the target version, validate:

```bash
docker compose --env-file .env --env-file versions.env config --quiet
docker compose --env-file .env --env-file versions.env up -d
docker compose --env-file .env --env-file versions.env ps
sh scripts/smoke-test.sh
```

Then check core app behavior manually:

- login works;
- projects load;
- assets/shots/tasks load;
- previews still resolve;
- new entities can be created;
- background jobs are running.

## Rollback

Rollback should mean returning to the previous Postgres image and previous data volume, not trying to downgrade an upgraded data directory.

Before a real upgrade, record:

- old `POSTGRES_VERSION`;
- old Postgres volume name;
- backup file names;
- tested restore command;
- exact validation result before the upgrade.

## Future Automation

A future helper may be modeled after the reference `docker-cgwire` upgrade compose files, but it should be added only after this manual flow is tested. The helper should use copied volumes or dump/restore artifacts and must not destroy the source volume automatically.
