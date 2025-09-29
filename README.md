# Kitsu — Production-ready Docker stack

Production-ready Docker compose for Kitsu (frontend) + Zou (backend) with Traefik (Let’s Encrypt), Postgres, backups and optional Redis/Meilisearch for local dev.

Features
- TLS + routing via Traefik
- Nginx-served frontend (Vite build) with API proxy
- Gunicorn-run backend with media deps (ffmpeg, libgl)
- Daily DB backups (configurable cron & retention)
- Local compose includes Redis & Meilisearch

Quickstart (prod)
1. Edit .env (KITSU_DOMAIN, LETSENCRYPT_EMAIL, DB creds, secrets).
2. docker compose up -d

Quickstart (local)
docker compose -f docker-compose.local.yml up --build
Frontend available at http://localhost:8080

Key files
.env, docker-compose.yml, docker-compose.local.yml, kitsu/, zou/, backups/backup.sh

