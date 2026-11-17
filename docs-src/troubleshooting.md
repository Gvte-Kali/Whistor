# Troubleshooting

## The page does not open from my PC

On the server:

```bash
docker compose ps
docker compose logs --tail=50 admin
docker compose port admin 8080
curl http://127.0.0.1:8080/health
```

Adjust the URL to your configured bind address and port. `127.0.0.1` in your PC's
browser refers to **your PC**, not the server, unless an SSH tunnel is active.
Then check your firewall, LAN routing or Tailscale policies.

With `WHISTOR_ADMIN_BIND=127.0.0.1`, use SSH/Tailscale Serve, or choose a
LAN/Tailscale address in `.env` and recreate `admin`.

## The page loads, but Synapse does not respond

```bash
docker compose logs --tail=100 synapse tor
curl http://127.0.0.1:8080/_matrix/client/versions
```

The static interface can become available before Synapse finishes starting.
On first startup, check that Tor has generated the expected hostname and that
volumes are shared correctly. A 502 error can also mean Synapse is stopped or
cannot be resolved from the internal Docker network.

## Login fails or permissions are missing

Use a **Synapse administrator** account, not your SSH password. An ordinary Matrix
account cannot manage users. To create an administrator:

```bash
export WHISTOR_DIR="$PWD"
./whistor user admin newadmin
```

Avoid editing SQLite directly while Synapse is running. If that username already
exists, choose another name or use an existing administrator to grant it privileges.

## Tailscale works, but the interface does not

Check that both devices are on the same tailnet, that the server listens on its
Tailscale IP or `0.0.0.0`, and that your policies allow TCP 8080. With Serve, use
`tailscale serve status` and the printed HTTPS URL. If you change the Docker port,
update Serve's target as well.

## A port is already in use

Change `WHISTOR_ADMIN_PORT` in `.env`, then run:

```bash
docker compose up -d --build admin
```

For SSH, you can choose a different **local** port such as `18080` while keeping
`8080` on the server.

## The CLI uses the wrong directory

From the directory containing `docker-compose.yml`:

```bash
export WHISTOR_DIR="$PWD"
./whistor admin
```

This overrides the default directory used by some CLI installations.

## Problems after an update

Check logs, Synapse upgrade notes and your backup. Do not delete volumes. See
[maintenance](maintenance.md) before restoring. When reporting a problem on
[GitHub](https://github.com/Gvte-Kali/Whistor/issues), include your Docker version,
checkout commit and logs with credentials, tokens, secrets and private keys removed.
