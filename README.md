# Kitsu — Production-ready Docker stack

This repository builds and composes a production-ready deployment of Kitsu (frontend) and Zou (backend) with supporting infrastructure (Traefik, PostgreSQL, backups, optional Redis / Meilisearch for local dev). It improves on the official single-image approach by adding TLS, reverse proxying, process management, system dependencies, backups, and sensible defaults for production.

Key files
- Compose (production): [docker-compose.yml](docker-compose.yml)
- Compose (local / dev): [docker-compose.local.yml](docker-compose.local.yml)
- Frontend build & serve: [kitsu/Dockerfile](kitsu/Dockerfile) and [kitsu/nginx.conf](kitsu/nginx.conf)
- Backend build & runtime: [zou/Dockerfile](zou/Dockerfile) and [`zou/gunicorn.conf.py`](zou/gunicorn.conf.py)
- Traefik static config: [traefik/traefik.yml](traefik/traefik.yml) and ACME helper: [traefik/acme.json](traefik/acme.json)
- DB backups: [backups/backup.sh](backups/backup.sh)
- Environment template: [.env](.env)

What makes this repo more production-ready than the official Kitsu docker image
- Automated HTTPS + routing
  - Traefik v3 as an edge reverse proxy with Docker provider and Let's Encrypt ACME configured in [docker-compose.yml](docker-compose.yml) and [traefik/traefik.yml](traefik/traefik.yml). Replace ${LETSENCRYPT_EMAIL} and ${KITSU_DOMAIN} in [.env](.env).
- Proper separation of concerns
  - Frontend built by [kitsu/Dockerfile](kitsu/Dockerfile) (Vite build) and served by Nginx with an API reverse-proxy (see [kitsu/nginx.conf](kitsu/nginx.conf)). This allows strip-prefixing and streaming endpoints (/previews/, /thumbnails).
- Production-ready backend
  - Zou is built from source in [zou/Dockerfile](zou/Dockerfile), installs system libs (ffmpeg, libgl1, etc.) required by media processing / OpenCV, and runs under Gunicorn. Gunicorn settings live in [`zou/gunicorn.conf.py`](zou/gunicorn.conf.py) (workers=4, threads=2, timeout=120) — tune as needed.
- Persistent storage & healthchecks
  - Postgres configured with a persistent volume and healthcheck in [docker-compose.yml](docker-compose.yml).
- Automated backups
  - Daily DB dumps managed by the `db-backup` service using [backups/backup.sh](backups/backup.sh). Configure schedule and retention with `BACKUP_CRON` and `BACKUP_RETENTION_DAYS` in [.env](.env).
- Local development compose
  - [docker-compose.local.yml](docker-compose.local.yml) includes Redis and Meilisearch for a full local environment and maps ports (e.g. 8080 for frontend).
- Security & configurable secrets
  - Secrets and runtime toggles live in [.env](.env): `ZOU_SECRET_KEY`, `POSTGRES_PASSWORD`, `KITSU_API_URL`, etc. Update before deploying.

Quickstart (production)
1. Copy and edit the environment file
   - Edit [.env](.env) and set `KITSU_DOMAIN`, `LETSENCRYPT_EMAIL`, DB credentials and secrets like `ZOU_SECRET_KEY`.
2. Bring up the stack
   - docker compose up -d
   - (Uses [docker-compose.yml](docker-compose.yml))
3. Monitor
   - Traefik dashboard, logs, and container healthchecks for issues.

Quickstart (local development)
1. Use the local compose file
   - docker compose -f docker-compose.local.yml up --build
   - (Uses [docker-compose.local.yml](docker-compose.local.yml) and exposes frontend at http://localhost:8080)
2. The local stack includes Redis and Meilisearch for indexer and caching.

Customization notes
- Gunicorn: change workers / threads in [`zou/gunicorn.conf.py`](zou/gunicorn.conf.py) or adapt to read `ZOU_WORKERS` / `ZOU_THREADS` from env.
- Frontend API path: the build ARG `VITE_API_URL` in [kitsu/Dockerfile](kitsu/Dockerfile) controls the URL baked into the frontend.
- Traefik routing: routers and labels are defined in [docker-compose.yml](docker-compose.yml). Ensure `KITSU_DOMAIN` matches DNS and Traefik labels.

Files to review for specific behavior
- [.env](.env) — environment and runtime tunables (including `ZOU_WORKERS`, `BACKUP_CRON`).
- [docker-compose.yml](docker-compose.yml) — production composition, Traefik integration and `db-backup`.
- [docker-compose.local.yml](docker-compose.local.yml) — local dev composition with Redis / Meilisearch.
- [kitsu/nginx.conf](kitsu/nginx.conf) — frontend routing, /api proxy and preview streaming.
- [zou/Dockerfile](zou/Dockerfile) — system dependencies for media processing and build steps.
- [backups/backup.sh](backups/backup.sh) — backup schedule, dump path and retention.

