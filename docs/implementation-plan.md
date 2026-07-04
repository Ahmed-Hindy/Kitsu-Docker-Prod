# Kitsu Docker Stack Hardening Plan

This document tracks the practical cleanup work for this repository. The goal is to improve reliability without changing the stack's basic purpose: a production-style Kitsu/Zou Docker Compose deployment that still works well on localhost.

## Phase 0 - Repository hygiene

- Normalize line endings with `.gitattributes` so YAML, Python, shell, Markdown, env, and config files do not keep producing noisy diffs.
- Ignore local-only files such as `.env`, `.venv`, editor folders, Traefik runtime state, and temporary query files.
- Keep tracked changes small and reviewable.

## Phase 1 - Image build correctness

- Keep the Zou image build context as `./zou`.
- Copy `gunicorn.conf.py` from inside that build context instead of referencing `../gunicorn.conf.py`.
- Validate the image build locally or through GitHub Actions before relying on new images.

## Phase 2 - Port clarity

- Separate host ports from internal container ports.
- Use `KITSU_WEB_HOST_PORT` for the browser-facing Kitsu/nginx port.
- Use `ZOU_API_HOST_PORT` for optional direct host access to Zou.
- Use `ZOU_API_INTERNAL_PORT` and `ZOU_EVENTS_INTERNAL_PORT` for container-internal service ports.

## Phase 3 - Operational documentation

- Keep the README short and focused on quick startup.
- Move operational details such as backups, restore, updating, and future upgrade work into dedicated files under `docs/`.

## Later phases

These are intentionally left for later commits because they are larger behavioral changes:

- Split Compose overlays into core, local, Traefik, backup, and development files.
- Add tested database and Meilisearch upgrade flows.
- Expand smoke tests into optional CI validation for Compose config and Docker builds.
- Revisit whether `zou-api` should be exposed directly on the host or only through nginx.
