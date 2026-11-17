# Architecture and network access

## Three services

```text
Tor-compatible Matrix client
    → Tor network → .onion:8448 service → synapse:8008

Browser on your PC (LAN / Tailscale / SSH)
    → server:8080 → admin (Ketesa + Nginx) → synapse:8008
```

| Service | Purpose | Docker networks |
| --- | --- | --- |
| `synapse` | Matrix homeserver and SQLite database | `matrix-internal` |
| `tor` | Hidden service and `.onion` identity | `matrix-internal`, `tor-external` |
| `admin` | Web interface and Synapse API proxy | `matrix-internal`, `admin-access` |

Only `admin` publishes a server port. Synapse does not directly publish a host port.
The browser uses the same origin for the interface and Matrix requests: it does
not need to resolve `synapse`, which is an internal Docker hostname.

## Access model

- The interface is reachable on your chosen network. Synapse authenticates the
  administrator account and checks permissions on API requests.
- The proxy forwards `/_matrix/` and `/_synapse/` to Synapse. Publishing the
  administration port also exposes these routes.
- The administration container cannot access the Docker socket, Tor keys or
  Synapse data volume. Its root filesystem is read-only, with in-memory temporary
  directories.
- Federation and public registration are disabled by the default configuration.
  This does not replace authentication or firewall rules.
- GitHub Pages hosts only this public documentation. It does not host your
  administration instance, passwords or private keys.

## Choose your exposure

Use your server's LAN address for local access. For private remote access, choose
direct Tailscale or Tailscale Serve. For remote access without a VPN, place an
HTTPS reverse proxy in front of the service. Variables in `.env` select the
interface and port without editing the Compose file.
