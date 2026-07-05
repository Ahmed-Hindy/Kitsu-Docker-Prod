# Compose Overlay Plan

The current supported path remains:

```bash
docker compose --env-file .env --env-file versions.env up -d
```

Do not split Compose files until the runtime behavior is stable enough that the split reduces maintenance risk. The first step is this plan, not a YAML move.

## Goals

- Keep the default local/LAN path copy-pasteable.
- Keep core services readable in the base compose file.
- Make optional operational surfaces explicit when they are eventually split.
- Validate every supported Compose file combination.

## Target Structure

When a split is justified, use this target shape:

```text
docker-compose.yml              core app services and internal dependencies
docker-compose.local.yml        localhost/LAN ports and Mailcatcher
docker-compose.traefik.yml      public HTTP/HTTPS routing
docker-compose.backups.yml      backup services
docker-compose.jobs.yml         optional job workers, if they become optional
docker-compose.upgrade.yml      future DB/indexer upgrade helpers
```

## Split Order

1. Document the supported command combinations before moving YAML.
2. Move one low-risk surface at a time.
3. Keep the base stack runnable after each step.
4. Update README commands and CI validation in the same change as any implemented split.

Good first candidates are Traefik or backups because they are operational surfaces around the core app. Avoid splitting core services until the dependency and startup model is settled.

## Validation Expectations

Any implemented overlay must preserve the current default workflow or clearly replace it with an equally simple command.

At minimum, validate:

```bash
docker compose --env-file .env --env-file versions.env config --quiet
docker compose --env-file .env.example --env-file versions.env config --quiet
```

For each supported overlay combination, add an explicit validation command in the README and CI before calling that combination supported.
