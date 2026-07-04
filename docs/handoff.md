# Kitsu Docker Stack Hardening Handoff

## Repository

```text
G:\Projects\Dev\Github\devspace-test\Docker_kitsu-prod
```

## Current branch

```text
dev/kitsu-stack-hardening-plan
```

This branch was created from the previous working branch and has not been committed or pushed yet.

## User preference

- Do not commit or push unless the user explicitly asks.
- Leave `.env` tracked for now.
- Keep changes practical and reviewable.
- Avoid a large Compose split until the current behavior is validated and committed.

## Current working tree summary

Expected `git status --short --ignored` state after this handoff file is added:

```text
 M .env
 M .gitattributes
 M README.md
 M docker-compose.yml
 M traefik/traefik.local.yml
 M zou/Dockerfile
 M zou/gunicorn.conf.py
?? .env.example
?? .gitignore
?? docs/backups.md
?? docs/handoff.md
?? docs/implementation-plan.md
!! .venv/
!! qc
!! query
```

Notes:

- `qc` and `query` are ignored local temp files. They only contained `Cloudflared` when inspected.
- `.venv/` is ignored.
- `.env` is intentionally still tracked, per user instruction.
- `traefik/traefik.local.yml` may still show modified due to line-ending/index metadata even if it has no meaningful diff.

## Changes already made

### Repository hygiene

Updated `.gitattributes` to normalize line endings for common project files:

- YAML
- Python
- shell scripts
- Markdown
- env files
- config files
- JSON
- Dockerfiles

Added `.gitignore` for local-only files:

- `.env.local`
- `.env.*.local`
- `.venv/`
- `qc`
- `query`
- `traefik/acme.json`
- editor and OS noise

`.env` was added to `.gitignore`, but because it is already tracked, it remains tracked. Do not untrack it unless the user explicitly agrees.

### Zou Docker build context fix

Fixed `zou/Dockerfile` so it no longer copies outside its Docker build context.

Old behavior:

```dockerfile
COPY ../gunicorn.conf.py /app/gunicorn.conf.py
```

New behavior:

```dockerfile
COPY gunicorn.conf.py /app/gunicorn.conf.py
```

This matches the GitHub Actions workflow, which builds Zou with:

```yaml
context: ./zou
file: ./zou/Dockerfile
```

### Port variable cleanup

Replaced ambiguous port variables with clearer host/internal names.

Old variables:

```env
KITSU_WEB_PORT=8080
ZOU_API_PORT=5001
ZOU_EVENTS_PORT=5001
```

New variables:

```env
KITSU_WEB_HOST_PORT=8080
ZOU_API_HOST_PORT=5001
ZOU_API_INTERNAL_PORT=8000
ZOU_EVENTS_INTERNAL_PORT=5001
```

`docker-compose.yml` now uses:

```yaml
- "${KITSU_WEB_HOST_PORT:-8080}:80"
- "${ZOU_API_HOST_PORT:-5001}:${ZOU_API_INTERNAL_PORT:-8000}"
```

The event server bind port now uses:

```yaml
${ZOU_EVENTS_INTERNAL_PORT:-5001}
```

### Environment example

Added `.env.example` with safe placeholder values and the current variable names.

### Documentation

Added:

```text
docs/implementation-plan.md
docs/backups.md
docs/handoff.md
```

Updated `README.md` to be shorter and more operational:

- quick start
- `.env.example` usage
- local/LAN settings
- Traefik notes
- backup docs link
- `versions.env` update flow
- difference from the official all-in-one image
- development notes

## Validation already completed

### Compose config validation

Both commands passed with no output/errors:

```bash
docker compose config --quiet
docker compose --env-file .env.example config --quiet
```

### Zou image build validation

The user ran this successfully from PowerShell:

```powershell
docker build -f zou/Dockerfile ./zou
```

Result summary:

- Build completed successfully.
- The final runtime stage successfully copied `gunicorn.conf.py` from the `./zou` context.
- This validates the Dockerfile context fix.

Relevant final build step:

```text
[stage-1 6/6] COPY gunicorn.conf.py /app/gunicorn.conf.py
```

### Stack startup validation

The user ran:

```powershell
docker compose pull
docker compose up -d
docker compose ps
```

Result summary:

- Images pulled successfully.
- Stack started successfully.
- `db` was healthy.
- `nginx` exposed `0.0.0.0:8080->80`.
- `zou-api` exposed `0.0.0.0:5001->8000`.
- `traefik` exposed ports 80 and 443.
- `db-backup`, `kitsu-web`, `zou-api`, `zou-events`, and `zou-init-db` started.

### HTTP validation

The user ran:

```powershell
curl http://localhost:8080/
curl http://localhost:8080/api
```

Results:

- `http://localhost:8080/` returned the Kitsu HTML shell.
- `http://localhost:8080/api` returned:

```json
{"api":"Zou","version":"1.0.52"}
```

This confirms the nginx frontend route and `/api` route work on localhost.

## Validation added after initial handoff

### Smoke test script

Added:

```text
scripts/smoke-test.sh
```

The script validates:

- `docker compose config --quiet`
- `docker compose --env-file .env.example config --quiet`
- `docker compose ps`
- `curl -fsS http://localhost:${KITSU_WEB_HOST_PORT:-8080}/`
- `curl -fsS http://localhost:${KITSU_WEB_HOST_PORT:-8080}/api` and checks that the response contains `"api":"Zou"`

The script intentionally reads only `KITSU_WEB_HOST_PORT` from `.env` instead of sourcing the full file because values such as `BACKUP_CRON=30 1 * * *` are valid for Docker Compose but fragile to source directly in `sh`.

Validation result:

```text
sh scripts/smoke-test.sh
[smoke-test] OK
```

### Manual backup validation

Plain Git Bash command failed because MSYS path conversion rewrote `/backup_once.sh` to `C:/Program Files/Git/backup_once.sh`:

```text
OCI runtime exec failed: exec: "C:/Program Files/Git/backup_once.sh": stat C:/Program Files/Git/backup_once.sh: no such file or directory
```

The Windows Git Bash-safe command succeeded:

```bash
MSYS_NO_PATHCONV=1 docker compose exec -T db-backup /backup_once.sh
MSYS_NO_PATHCONV=1 docker compose exec -T db-backup ls -lh /backups
```

Created backup:

```text
/backups/kitsu_20260704_162846.sql.gz
```

`docs/backups.md` was updated with the Windows Git Bash note.

### Event/websocket route validation

The Socket.IO polling endpoint returned a valid session payload:

```bash
curl -fsS 'http://localhost:8080/socket.io/?EIO=4&transport=polling'
```

The nginx logs also showed a successful websocket upgrade from a browser session:

```text
GET /socket.io/?EIO=4&transport=websocket ... 101
```

Browser login was validated manually by the user after these checks.

### Additional finding

`zou-events` logs show this warning with the current tracked `.env`:

```text
InsecureKeyLengthWarning: The HMAC key is 16 bytes long, which is below the minimum recommended length of 32 bytes for SHA256.
```

Cause: the current tracked `.env` uses `ZOU_SECRET_KEY=mysecretpassword`. The README already recommends generating a strong value with `openssl rand -hex 32`. Leave `.env` tracked and unchanged unless the user approves changing local secrets.

### Branch validation workflow

Added a non-publishing workflow:

```text
.github/workflows/validate-stack.yml
```

It runs on pushes to `main` and `dev/**`, pull requests, and manual dispatch. It validates Compose config and builds the Zou, Kitsu web, and db-backup Docker images without publishing them.

The first run passed Compose validation but failed the Zou build because `versions.env` was still indexed with CRLF endings. The parsed tag became `v1.0.52\r`, which Git reported as `v1.0.52?`. The workflow now strips carriage returns when reading versions, and `versions.env` was renormalized to LF.

This avoids manually dispatching the publish workflow on this branch. The publish workflow uses `github.ref_name` as the image tag, so a branch name containing slashes would be a bad Docker tag unless that workflow is hardened separately.

PR review found and fixed a merge-resolution regression: `main` had moved `db-backup` to a custom image with `supercronic`, but the conflict resolution temporarily kept plain `postgres:15`. The Compose file now uses the custom `kitsu-db-backup` image/build context again, and validation CI builds that image.

## Known caveats / not yet validated

These still need follow-up:

1. Mailcatcher user-invite workflow has not been checked.
2. Restore flow is documented but not tested.
3. GitHub Actions image build has not been re-run for this branch.
4. `.env` remains tracked by user request, even though `.env.example` now exists.

## Recommended next steps

### 1. Review the diff

Run:

```bash
git diff -w --stat
git diff -w -- docker-compose.yml .env zou/Dockerfile README.md
```

Check that the meaningful changes are limited to:

- Dockerfile context fix
- port variable naming cleanup
- docs and README cleanup
- repo hygiene files

### 2. Resolve line-ending-only noise

Check whether `traefik/traefik.local.yml` has meaningful changes:

```bash
git diff -- traefik/traefik.local.yml
git diff -w -- traefik/traefik.local.yml
```

If both are empty or only line-ending noise, normalize or restore it carefully before commit.

### 3. Keep using the smoke-test script

Run:

```bash
sh scripts/smoke-test.sh
```

Keep the script simple. Do not add complex login/API-auth tests yet.

### 4. Run browser-level checks

Open:

```text
http://localhost:8080/
```

Check:

- Login works.
- Project list loads.
- Browser console has no obvious websocket/event spam.
- `/api/config` loads.

### 5. Optional backup re-check

Backup creation was validated from Git Bash with `MSYS_NO_PATHCONV=1`. Re-check only if backup scripts or Compose volume wiring change.

### 6. Commit only after review and validation

Suggested commit message:

```text
Harden Kitsu Docker stack configuration
```

Do not push unless the user asks.

## Defer until after first commit

Do not do these yet unless the user explicitly asks:

- Split Compose into multiple override files.
- Untrack `.env`.
- Remove direct host exposure of `zou-api`.
- Add DB or Meilisearch upgrade scripts.
- Rewrite the Traefik/nginx architecture.

Those are valid future improvements, but they are larger behavioral changes and should happen after the current branch is reviewed and committed.

## New-chat continuation prompt

Use this prompt in a new chat:

```text
@DevSpace Local continue work on:
G:\Projects\Dev\Github\devspace-test\Docker_kitsu-prod

Current branch:
dev/kitsu-stack-hardening-plan

Read first:
1. docs/handoff.md
2. docs/implementation-plan.md
3. docs/backups.md
4. README.md

Important preferences:
- Do not commit or push unless I explicitly ask.
- Leave .env tracked for now.
- Keep changes minimal and reviewable.
- Do not split Compose files yet unless I approve.

Current goal:
Continue hardening and validating the Kitsu Docker stack after the initial cleanup.

Already done:
- Added .gitattributes and .gitignore.
- Added .env.example.
- Fixed zou/Dockerfile so it copies gunicorn.conf.py from inside ./zou.
- Clarified Kitsu/Zou host/internal port variables.
- Updated README.md.
- Added docs/implementation-plan.md, docs/backups.md, and docs/handoff.md.
- Added scripts/smoke-test.sh.
- docker compose config --quiet passes.
- docker compose --env-file .env.example config --quiet passes.
- sh scripts/smoke-test.sh passes.
- docker build -f zou/Dockerfile ./zou succeeded.
- docker compose pull/up/ps succeeded.
- curl http://localhost:8080/ returns Kitsu HTML.
- curl http://localhost:8080/api returns {"api":"Zou","version":"1.0.52"}.
- Socket.IO polling returns a session payload.
- nginx logs show successful websocket upgrade with HTTP 101 from a browser session.
- Manual backup creation succeeded from Git Bash with MSYS_NO_PATHCONV=1.

Next recommended steps:
1. Push the branch validation workflow and review its run status.
2. Mailcatcher invite/email workflow can be tested next.
3. Decide later whether to change the tracked local ZOU_SECRET_KEY to remove the 16-byte key warning, or leave it as local-demo-only.
4. Keep larger architecture changes deferred until explicitly approved.
```
