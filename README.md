
# Kitsu Docker (Production-Style Stack)

This Docker stack runs **Kitsu** (frontend) + **Zou** (backend) + **Postgres** + **Traefik** using Docker Compose.

You don’t need to build anything locally – images are already published to GitHub Container Registry (GHCR).

</br>






## 1. Quick Start (Production)

### Step 1 – Clone this repo

```bash
git clone https://github.com/Ahmed-Hindy/Kitsu-Docker-Prod.git
cd Kitsu-Docker-Prod
```

### Step 2 (Optional) – Edit `.env`

You can edit the `.env`:

```env
# Domain and TLS
KITSU_DOMAIN=kitsu.example.com  # if you have a domain

# First Kitsu admin (Login with these )
ZOU_ADMIN_EMAIL=admin@example.com
ZOU_ADMIN_PASSWORD=mysecretpassword

# Backups
BACKUP_RETENTION_DAYS=14
```

Optional: Generate a secret key (for `ZOU_SECRET_KEY`):

```bash
openssl rand -hex 32
```

### Step 3 – Pull images and start the containers

```bash
docker compose pull
docker compose up -d
```

Now open the URL for kitsu web, default is:

```text
http://localhost:8080/
```

Login with:

* Email: `admin@example.com`
* Password: `mysecretpassword`

That’s it. You have a Kitsu Pipeline up and running.

---


## 4. Backups (Postgres)

This stack runs automatic Postgres backups in a separate `db-backup` container.

* Schedule: `BACKUP_CRON` in `.env` (default: every night at 01:30)
* Retention: `BACKUP_RETENTION_DAYS` in `.env` (default: 14 days)
* Files stored in the `backups` Docker volume

Trigger a manual backup:

```bash
docker exec -it <db-backup-container-name> /bin/bash -lc "/backup_once.sh"
```

List backup files:

```bash
docker exec -it <db-backup-container-name> ls -lh /backups
```

---

## 5. Updating to New Versions

Images are built and pushed to GHCR by GitHub Actions.

The software versions (Kitsu/Zou) are pinned in the `versions.env` file. This allows independent updates of the Docker setup and the application versions.

### How to update Kitsu/Zou?
1. Edit `versions.env` locally to the desired version:
   ```env
   ZOU_VERSION=1.0.4
   KITSU_VERSION=1.0.4
   ```
2. Commit and push the change.
3. GitHub Actions will build new images with those specific versions.

### How to update your deployment?

To update:

1. Pull new images:

   ```bash
   docker compose pull
   ```

2. Restart services:

   ```bash
   docker compose up -d
   ```

---




</br>
</br>

## 6. How This Stack Differs From the Official Kitsu Docker Image

There is an official “all-in-one” Kitsu Docker image (`cgwire/cgwire`) that you can run with a single `docker run` command. This project is **different** and more “production style”.

### Official `cgwire/cgwire` image

* Single container with:

  * Postgres
  * Zou
  * Kitsu frontend
  * Mailcatcher

* Quick trial with:

  ```bash
  docker run -d -p 80:80 --name cgwire cgwire/cgwire
  ```

* Basic persistent storage if you mount volumes manually.

* Good for **trying Kitsu quickly on one machine**, but:

  * No Traefik
  * No FFMPEG for generating previews
  * No automatic Let’s Encrypt
  * No separate backup service
  * Everything runs in one container

### This repo (Kitsu-Docker-Prod)

* Multi-container, production-style architecture:

  * `kitsu-web` (frontend)
  * `zou-api` (backend)
  * `db` (Postgres)
  * `traefik` (reverse proxy + HTTPS)
  * `db-backup` (automated backups)
  * `Mailcatcher` (local mail for creating new Kitsu users)
  * extras (Redis, Meilisearch for local/dev)




---

