# Kitsu Docker Stack Handoff

This file summarizes the practical state of PR #19 and the follow-up work for future agents or maintainers.

## Branch and PR

- Branch: `dev/kitsu-stack-hardening-plan`
- PR: `https://github.com/Ahmed-Hindy/Kitsu-Docker-Prod/pull/19`
- Base branch: `main`

## Scope of this PR

This PR keeps the stack architecture intact. It does not split Compose files or replace the deployment model.

Included changes:

- Add `.gitattributes` for LF normalization.
- Add `.gitignore` for local-only files.
- Add `.env.example` as a safe local template while leaving tracked `.env` in place.
- Rename ambiguous host/internal port variables:
  - `KITSU_WEB_PORT` -> `KITSU_WEB_HOST_PORT`
  - `ZOU_API_PORT` -> `ZOU_API_HOST_PORT`
  - add `ZOU_API_INTERNAL_PORT`
  - add `ZOU_EVENTS_INTERNAL_PORT`
- Keep explicit application and backup image tags in `versions.env`.
- Keep Postgres and Meilisearch image tags in `versions.env` without upgrading them.
- Keep Compose image references tied to those explicit tags instead of relying on implicit defaults.
- Fix the Zou Dockerfile so `gunicorn.conf.py` is copied from inside the `./zou` build context.
- Add a local smoke-test script.
- Add a non-publishing CI workflow that validates Compose config and builds the Zou, Kitsu web, and db-backup images.
- Add operational backup documentation.

## Important merge-resolution note

`main` had moved `db-backup` to a custom image built from `backups/Dockerfile`. That image installs `supercronic`, which the current `backups/backup.sh` requires.

During conflict resolution, `db-backup` briefly regressed to plain `postgres:15`. That was fixed in this PR. The Compose file now keeps:

```yaml
build:
  context: ./backups
image: ghcr.io/ahmed-hindy/kitsu-db-backup:${BACKUP_IMAGE_TAG:?Set BACKUP_IMAGE_TAG in versions.env}
```

The validation workflow now also builds `backups/Dockerfile` so this regression is caught in CI.

## Validation performed

Local checks that passed:

```bash
git diff --check
docker compose --env-file .env --env-file versions.env config --quiet
docker compose --env-file .env.example --env-file versions.env config --quiet
docker build -f zou/Dockerfile ./zou
docker build -f backups/Dockerfile ./backups
```

Runtime checks performed earlier on this branch:

- `docker compose pull` and `docker compose up -d` succeeded.
- Kitsu loaded on `http://localhost:8080/`.
- `/api` returned Zou version info.
- Browser login was manually validated by the user.
- Socket.IO polling and websocket upgrade were validated.
- Manual backup creation was validated.

## Windows Git Bash backup note

When running manual backup commands from Git Bash on Windows, disable MSYS path conversion:

```bash
MSYS_NO_PATHCONV=1 docker compose --env-file .env --env-file versions.env exec db-backup /backup_once.sh
MSYS_NO_PATHCONV=1 docker compose --env-file .env --env-file versions.env exec db-backup ls -lh /backups
```

Without `MSYS_NO_PATHCONV=1`, Git Bash may rewrite `/backup_once.sh` into a Windows path.

## Known caveats

- `.env` remains tracked by request.
- `.env` still contains local/demo credentials and should be changed before real deployment.
- Restore documentation exists, but a full restore test was not performed in this PR.
- Mailcatcher invite/email workflow was not fully tested.
- Larger architecture work, such as implementing Compose overlays, remains deferred. The overlay strategy is documented in `docs/compose-overlays.md`.
- Postgres and Meilisearch version changes are documented as separate upgrade work in `docs/upgrades.md`.

## Recommended next phase

After this PR merges, the next useful phase is to validate the Mailcatcher invite/email workflow and document the exact user-management flow. Compose splitting should remain deferred until the current stack behavior is stable.
