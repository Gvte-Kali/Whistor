# Updates and backups

## Understand `latest`

Synapse uses `ghcr.io/element-hq/synapse:latest`. The administration image is built
from Ketesa `latest` and Nginx `stable-alpine`. Versions change over time; an
upgrade may include database migrations.

Before updating, review the
[Synapse upgrade notes](https://element-hq.github.io/synapse/latest/upgrade.html),
including the notes for every intermediate version you skip.

## Back up your deployment

Keep these items:

| Item | Why it matters |
| --- | --- |
| `tor-data` volume | Private keys and the `.onion` identity |
| `synapse-data` volume | Database, configuration, media and signing key |
| `.env` and deployment files | Network settings and reproducible configuration |

Volume names usually include the Compose project prefix. Check them with
`docker volume ls`; do not assume they always start with `whistor_`.

For a consistent SQLite backup, stop services that write data before archiving.
From your deployment directory on the server:

```bash
mkdir -p backups
docker compose stop synapse tor admin
docker compose run --rm --no-deps --user 0 --entrypoint /bin/sh \
  -v "$PWD/backups:/backup" synapse \
  -c 'tar -czf /backup/whistor-data.tar.gz -C /data .'
docker compose run --rm --no-deps --user 0 --entrypoint /bin/sh \
  -v "$PWD/backups:/backup" tor \
  -c 'tar -czf /backup/whistor-tor.tar.gz -C /var/lib/tor/hidden_service .'
docker compose up -d
```

These commands overwrite the two archives if they already exist. Move each backup
to a dated directory before creating another. Also copy `.env` and record the
checkout commit (`git rev-parse HEAD`) and image references (`docker compose images`).
Keep a restricted-access copy off the server.

The `./whistor backup` command is also available, but uses predefined volume names
and does not pause Synapse. Check those assumptions before relying on it for a
critical backup.

## Update the source and images

On **the server**, after backing up:

```bash
cd /path/to/Whistor
export WHISTOR_DIR="$PWD"
git pull --ff-only
./whistor update
```

`whistor update` pulls Synapse and Tor images, rebuilds administration with the
latest base images, then recreates containers. It does **not** run `git pull` for
you. Afterwards, check `docker compose ps`, logs and a test login from your PC.

## Restore

Restore into an isolated environment first when possible. Use images and source
matching your backup. Stop services, then restore each archive to its corresponding
volume, preserving ownership and permissions. Restore `.env` before restarting.

Do not start an older Synapse version on a database migrated by a newer version:
rolling back also requires the matching data backup. Do not run
`docker compose down -v` on your deployment to troubleshoot an incident. It deletes
volumes and can permanently destroy your `.onion` identity.
