# Web administration and users

## Choose your access method

| Method | Open on your PC | Requirements |
| --- | --- | --- |
| LAN, without a VPN | `http://SERVER_LAN_IP:8080` | Same network or LAN routing; firewall allowing TCP 8080 |
| Direct Tailscale | `http://SERVER_TAILSCALE_IP:8080` | Both devices on the same tailnet; policy allowing TCP 8080 |
| Tailscale Serve | HTTPS URL printed by Tailscale | Serve/HTTPS enabled for your tailnet |
| SSH | `http://localhost:8080` after opening a tunnel | SSH access to the server |
| Internet without a VPN | Your HTTPS domain | An HTTPS reverse proxy on the server |

## LAN: the direct route

The service listens on `0.0.0.0:8080` by default. On your PC, open
`http://192.168.1.42:8080`, replacing the example address with your server's IP.
No Matrix proxy or Tor configuration is needed for administration.

Your server firewall and network rules must allow the connection. Allow the
networks you intend to use; Whistor does not modify your firewall automatically.

## Direct Tailscale access

Install Tailscale on **both the server and your PC**, join the same tailnet, then
check the server's address:

```bash
tailscale ip -4
```

On your PC, open `http://THE_PRINTED_ADDRESS:8080`. Tailnet policies must allow your
PC to reach that port. No public port forwarding on your router is required.

## Tailscale Serve with HTTPS

On **the server**:

```bash
tailscale serve --bg http://127.0.0.1:8080
tailscale serve status
```

Open the printed HTTPS URL from your PC connected to the tailnet. Tailscale may
ask you to enable Serve and HTTPS. This uses **Serve**, not Funnel: access stays
private to your tailnet.

For access exclusively through this method, set `WHISTOR_ADMIN_BIND=127.0.0.1` in
`.env` and recreate the service.

## SSH tunnel

Run this on **your PC** and keep the terminal open:

```bash
ssh -N -L 8080:127.0.0.1:8080 USER@SERVER
```

Then open `http://localhost:8080`. If your local port is already in use:

```bash
ssh -N -L 18080:127.0.0.1:8080 USER@SERVER
```

In that case, open `http://localhost:18080` in your browser.

## Change the port or bind address

In `.env`, next to `docker-compose.yml`:

```dotenv
WHISTOR_ADMIN_BIND=0.0.0.0
WHISTOR_ADMIN_PORT=8080
```

| Bind address | Effect |
| --- | --- |
| `0.0.0.0` | All IPv4 interfaces, including LAN and Tailscale |
| Server's LAN IP | Only that interface |
| Server's Tailscale IP | Only that interface; it must exist when the service starts |
| `127.0.0.1` | Local access, SSH, Tailscale Serve or a local reverse proxy |

Apply changes on **the server**:

```bash
docker compose up -d --build admin
```

Update your URLs and tunnel commands if you change the port.

## Manage accounts

1. Sign in with a **Synapse administrator** account, separate from your Linux login.
2. Search for an account in the users list or create a new one.
3. Change its display name, password or privileges as needed.
4. Deactivate an account to remove access. Deactivation does not automatically mean
   that all associated data is erased.
5. Keep at least one working administrator and sign out when finished.

Synapse checks permissions: an ordinary user cannot call the administration APIs,
even if they can open the login page.

## Internet access without a VPN

Put an HTTPS reverse proxy in front of `http://127.0.0.1:8080`. Use a dedicated
hostname at `/`, preserve the `Host` header and send `X-Forwarded-Proto: https`.
Deploying under a URL subpath is not supported.

Do not send administrator credentials over the Internet using HTTP; use HTTPS.
Publishing this proxy also makes the relayed Matrix APIs reachable at that address.
Choose network access rules accordingly.
