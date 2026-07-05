# Meilisearch Upgrade Runbook

This runbook is for a future Meilisearch version upgrade. Do not use it for normal Kitsu or Zou application updates.

The current stack keeps Meilisearch pinned in `versions.env` and stores index data in the `kitsu_meili` named volume. Meilisearch can have version-specific index formats, so changing `MEILI_VERSION` should be treated as an infrastructure migration.

## Goals

- Avoid losing search/index data unexpectedly.
- Keep the source index volume untouched until the upgraded stack is accepted.
- Confirm Zou can talk to the target Meilisearch version.
- Separate indexer upgrades from unrelated app or database changes.

## Before You Start

1. Confirm the target Meilisearch version is supported by the current Zou version.
2. Read the Meilisearch release notes for upgrade constraints between the current and target versions.
3. Confirm whether the current version supports the target upgrade path directly or requires intermediate versions.
4. Run a fresh database and preview backup before changing infrastructure.
5. Record the current `MEILI_VERSION` and volume name.

Useful checks:

```bash
docker compose --env-file .env --env-file versions.env ps
docker compose --env-file .env --env-file versions.env exec meilisearch wget -qO- http://127.0.0.1:${MEILI_PORT:-7700}/health
```

## Recommended Migration Strategy

For early versions of this repository, prefer a rebuildable-index strategy unless a tested Meilisearch dump or upgrade helper exists.

High-level flow:

1. Take normal application backups first.
2. Stop services that write to Meilisearch.
3. Keep the old `kitsu_meili` volume available for rollback.
4. Create a new Meilisearch volume for the target version or explicitly clear/rebuild only after confirming the old data is recoverable.
5. Start Meilisearch with the target version.
6. Run Zou index reset/rebuild commands if required by the chosen strategy.
7. Run the smoke test and manually confirm search behavior.

Do not delete the old Meilisearch volume during the same maintenance window.

## Validation

After changing the indexer version or data volume, validate:

```bash
docker compose --env-file .env --env-file versions.env config --quiet
docker compose --env-file .env --env-file versions.env up -d
docker compose --env-file .env --env-file versions.env ps
sh scripts/smoke-test.sh
```

Then check app behavior manually:

- project search works;
- asset/shot search works;
- task lists load;
- new entities appear in search after creation;
- `zou-jobs` remains running and connected to Redis.

## Rollback

Rollback should mean returning to the previous Meilisearch image and previous index volume, or rebuilding the index from the preserved Postgres data. Do not assume Meilisearch index data can be downgraded after a newer version writes to it.

Before a real upgrade, record:

- old `MEILI_VERSION`;
- old Meilisearch volume name;
- target `MEILI_VERSION`;
- whether the migration uses a copied volume, dump, or rebuild;
- exact validation result before the upgrade.

## Future Automation

A future helper may be modeled after the reference `docker-cgwire` indexer upgrade compose file. Add it only after testing the exact version path used by this stack. The helper should copy or rebuild into a separate target volume and must not overwrite the source volume automatically.
