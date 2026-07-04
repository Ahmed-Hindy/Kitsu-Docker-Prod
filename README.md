# Kitsu Docker Production Stack

This Docker Compose stack runs Kitsu, Zou, Postgres, Redis, Meilisearch, Traefik, Mailcatcher, and automated Postgres backups.

The Kitsu and Zou application images are prebuilt and published to GitHub Container Registry. You do not need to build anything locally for a normal deployment.

## Screenshot

![Kitsu running in the Docker stack](docs/images/kitsu-running.png)

## Prerequisites

Install:

* Docker Engine or Docker Desktop
* Docker Compose v2 or newer
* Git

Check Docker:

```bash
docker compose version
```

## Quick Start

1. Clone the repository:

   ```bash
   git clone https://github.com/Ahmed-Hindy/Kitsu-Docker-Prod.git
   cd Kitsu-Docker-Prod
   ```

2. Review `.env`.

   The repository includes a working local/LAN `.env`. Before using this for a real deployment, change at least:

   ```env
   KITSU_DOMAIN=kitsu.example.com
   LETSENCRYPT_EMAIL=admin@example.com
   ZOU_SECRET_KEY=<generate-a-long-random-secret>
   ZOU_ADMIN_EMAIL=admin@example.com
   ZOU_ADMIN_PASSWORD=<choose-a-strong-password>
   ```

   Generate a secret key with:

   ```bash
   openssl rand -hex 32
   ```

   The default direct web port is controlled by:

   ```env
   KITSU_WEB_PORT=8080
   ```

3. Keep `versions.env` with the deployment.

   Docker Compose uses this file to pull explicit Kitsu/Zou image tags:

   ```env
   ZOU_VERSION=v1.0.52
   KITSU_VERSION=v1.0.48
   ```

4. Pull and start the stack:

   ```bash
   docker compose --env-file .env --env-file versions.env pull
   docker compose --env-file .env --env-file versions.env up -d
   ```

5. Verify the containers:

   ```bash
   docker compose --env-file .env --env-file versions.env ps
   ```

6. Open Kitsu:

   ```text
   http://localhost:8080/
   ```

   If you changed `KITSU_WEB_PORT`, use that port instead.

## Default Login

The first admin user is created by the `zou-init-db` service from these `.env` values:

```env
ZOU_ADMIN_EMAIL=admin@example.com
ZOU_ADMIN_PASSWORD=mysecretpassword
```

If you change those values after the database has already been initialized, the existing admin account is not reset automatically.

## Public Access And TLS

The stack exposes two entry paths:

* Direct local/LAN access through `http://<host>:${KITSU_WEB_PORT}`
* Traefik on `${TRAEFIK_HTTP_PORT}` and `${TRAEFIK_HTTPS_PORT}`

For Let's Encrypt certificates, set `KITSU_DOMAIN` to a real DNS hostname that points to this host. A LAN IP address is fine for HTTP routing, but public certificate issuance requires DNS.

## Useful URLs

With the default `.env`:

```text
Kitsu:       http://localhost:8080/
Mailcatcher: http://localhost:1080/
Zou API:     http://localhost:5001/
```

## Updating The Deployment

Images are built and pushed to GHCR by GitHub Actions.

The Kitsu and Zou versions are pinned in `versions.env`. Deployment commands must load both `.env` and `versions.env` so Compose pulls the explicit application-version tags instead of `latest`.

To update Kitsu or Zou:

1. Edit `versions.env`.
2. Commit and push the change.
3. Wait for the image build workflow to finish.
4. Pull and recreate the stack:

   ```bash
   docker compose --env-file .env --env-file versions.env pull
   docker compose --env-file .env --env-file versions.env up -d
   docker compose --env-file .env --env-file versions.env restart nginx
   ```

The `nginx` restart refreshes Docker DNS resolution after app containers are recreated.

## Backups

This stack runs automatic Postgres backups in the `db-backup` container.

* Schedule: `BACKUP_CRON` in `.env` (default: every day at 01:30 UTC)
* Retention: `BACKUP_RETENTION_DAYS` in `.env` (default: 14 days)
* Storage: the `kitsu_backups` Docker volume

Trigger a manual backup:

```bash
docker compose --env-file .env --env-file versions.env exec db-backup /bin/bash -lc "/backup_once.sh"
```

List backup files:

```bash
docker compose --env-file .env --env-file versions.env exec db-backup ls -lh /backups
```

## Common Commands

View logs:

```bash
docker compose --env-file .env --env-file versions.env logs -f
```

Restart the stack:

```bash
docker compose --env-file .env --env-file versions.env restart
```

Stop the stack without deleting data:

```bash
docker compose --env-file .env --env-file versions.env down
```

Remove the stack and named volumes:

```bash
docker compose --env-file .env --env-file versions.env down -v
```

## Architecture

This project uses separate containers instead of the official all-in-one `cgwire/cgwire` image:

* `kitsu-web` for the frontend
* `zou-api` for the API
* `zou-events` for Socket.IO events
* `db` for Postgres
* `redis` for the key/value store
* `meilisearch` for indexing
* `nginx` as the Kitsu/Zou frontend proxy
* `traefik` for public HTTP/HTTPS routing
* `db-backup` for automated database backups
* `mailcatcher` for local development mail

The official `cgwire/cgwire` image is useful for trying Kitsu quickly on one machine. This stack is intended to be closer to a production-style deployment with separate services, reverse proxying, and backups.
