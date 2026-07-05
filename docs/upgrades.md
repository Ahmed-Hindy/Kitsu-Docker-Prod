# Upgrade Notes

This stack keeps image tags in `versions.env` so deployment versions are visible in one place. Editing a tag is not always a safe upgrade by itself.

## Application Images

Kitsu, Zou, and the backup helper image can usually be updated by changing:

```env
ZOU_VERSION=v1.0.52
KITSU_VERSION=v1.0.48
BACKUP_IMAGE_TAG=main
```

After changing those values, validate and recreate the stack with the commands in the README.

## Postgres

`POSTGRES_VERSION=15` currently renders the same `postgres:15` image that the stack used before this refactor.

Do not bump `POSTGRES_VERSION` as part of an unrelated change. A Postgres major-version upgrade needs a separate tested plan that includes:

- a fresh backup before any migration work;
- a restore or rollback path;
- confirmation that Zou supports the target Postgres version;
- validation against a copy of the real data volume or a representative test dataset.

## Meilisearch

`MEILI_VERSION=v1.11` currently renders the same `getmeili/meilisearch:v1.11` image that the stack used before this refactor.

Do not bump `MEILI_VERSION` as part of an unrelated change. A Meilisearch upgrade needs a separate tested plan that includes:

- a backup or rebuild plan for the Meilisearch data volume;
- review of Meilisearch release notes for breaking index or dump-format changes;
- confirmation that Zou supports the target Meilisearch version;
- validation that indexing and search still work after the change.

## Validation

For version-file changes that do not intentionally upgrade Postgres or Meilisearch, confirm the rendered images still include:

```text
postgres:15
getmeili/meilisearch:v1.11
```

Use:

```bash
docker compose --env-file .env --env-file versions.env config --images
docker compose --env-file .env --env-file versions.env config --quiet
docker compose --env-file .env.example --env-file versions.env config --quiet
```
