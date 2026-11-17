# Whistor

📚 **[GitHub Pages documentation](https://gvte-kali.github.io/Whistor/)** — installation, web administration, LAN/Tailscale/SSH access, updates, backups and troubleshooting.

> A self-hosted Matrix (Synapse) homeserver with a Tor v3 hidden service and optional network administration access.
> Matrix over Tor, with a web administration interface on port 8080 for LAN or Tailscale access.


### One-liner install
```bash
curl -fsSL https://raw.githubusercontent.com/Gvte-Kali/Whistor/refs/heads/main/install.sh | bash
```
### Use Client : 
https://github.com/Gvte-Kali/element-tor
---

## Table of Contents

- [Hardware & OS requirements](#hardware--os-requirements)
- [How it works](#how-it-works)
- [Server requirements](#server-requirements)
- [Install the server](#install-the-server)
- [Managing the stack](#managing-the-stack)
- [Web administration from your PC](#web-administration-from-your-pc)
- [Creating users](#creating-users)
- [Client setup](#client-setup)
  - [Android](#android)
  - [iOS](#ios)
  - [Desktop (Linux / macOS / Windows)](#desktop-linux--macos--windows)
  - [Quick reference table](#quick-reference-table)
- [Backup & restore](#backup--restore)
- [Security](#security)
- [Project structure](#project-structure)

---

## Hardware & OS requirements

### Minimum specs

| Component | Minimum | Recommended |
|---|---|---|
| CPU | 1 vCPU | 2 vCPU |
| RAM | 1 GB | 2 GB |
| Storage | 10 GB SSD | 20 GB SSD |
| Network | Any | 100 Mbps+ |
| Architecture | x86_64 | x86_64 |

> Storage grows over time with message history and media files.
> Plan for ~1 GB/month per active user sending media.

---

### Recommended OS

**Debian 12 or Ubuntu 24.04 LTS** — best Docker compatibility, well-documented,
long-term support. Most cloud providers offer these out of the box.

Other compatible systems: any Linux distro that supports Docker 20.x+.
Windows and macOS are **not** supported for the server.

---

### Recommended hardware

whistor is designed to run on minimal hardware. Federation is disabled, so
resource usage stays low regardless of room size — only your users matter.

**For a small private group (2–10 users) — quick and cheap:**

| | Option |
|---|---|
| 🥇 Best value | **Hetzner CX22** — 2 vCPU, 4 GB RAM, 40 GB SSD — ~€4/month |
| 🥈 Cheapest | **Oracle Cloud Free Tier** — 1 vCPU, 1 GB RAM — free forever |
| 🏠 Self-hosted | **Raspberry Pi 4** (4 GB RAM) + SSD — one-time cost, runs at home |

**For a larger group (10–50 users):**

| | Option |
|---|---|
| 🥇 Recommended | **Hetzner CX32** — 4 vCPU, 8 GB RAM, 80 GB SSD — ~€9/month |
| 🥈 Alternative | **DigitalOcean Droplet** — 2 vCPU, 4 GB RAM — ~$24/month |

> **Why Hetzner?** European datacenters, competitive pricing, simple interface,
> reliable uptime. No affiliation — just the community standard for self-hosting.

---

## How it works

```
  Matrix client (Element + SOCKS5 Tor proxy)
        │
        ▼  .onion address
  ┌──────────────────┐
  │   Tor daemon     │  ← container: goldy/tor-hidden-service
  │   port 8448      │
  └────────┬─────────┘
           │  Docker internal network only (no host exposure)
           ▼  synapse:8008
  ┌──────────────────┐
  │   Synapse        │  ← container: ghcr.io/element-hq/synapse
  │   homeserver     │
  └──────────────────┘
```

- Synapse **never** binds to the host machine's network interface; administration is proxied through the web UI
- The `.onion` Matrix endpoint uses Tor; the administration service also proxies the Matrix client and admin APIs on its configured network address.
- Matrix federation is disabled — this is a fully isolated private server
- The `.onion` address is stable across restarts (private keys persisted in a Docker volume)
- All secrets are randomly generated on first boot

---

## Server requirements

- Linux (Debian/Ubuntu recommended)
- [Docker](https://docs.docker.com/get-docker/) ≥ 20.x
- [Docker Compose](https://docs.docker.com/compose/install/) v2 (plugin) or v1 (standalone)
- `curl` or `wget`
- `git` (optional — files are fetched individually as a fallback)

---

## Install the server

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/Gvte-Kali/Whistor/refs/heads/main/install.sh | bash
```

### Manual

```bash
git clone https://github.com/Gvte-Kali/whistor.git
cd whistor
docker compose up -d
```

### What happens during install

1. Dependencies are checked (Docker, Docker Compose, curl/wget)
2. The repository is cloned into `~/whistor`
3. The `whistor` CLI command is installed into `/usr/local/bin`
4. The Docker stack is started
5. The script waits for Tor to generate the hidden service `.onion` address
6. A `whistor.config` file is written to the install directory with all client parameters

```bash
# Read your full client configuration at any time
whistor config
```

---

## Updating Synapse

The stack follows the upstream `ghcr.io/element-hq/synapse:latest` image.
Compatibility was checked with stable Synapse **1.165.0** on 2026-11-17.
Before running `whistor update`, run `whistor backup` and read the
[upgrade notes](https://element-hq.github.io/synapse/latest/upgrade.html) for every
skipped version. Database migrations can prevent downgrades.

`whistor update` pulls the current images and recreates the containers, keeping
the Tor keys and Synapse volumes. It does not update the repository checkout.
Restore a matching data backup if you need to return to an older Synapse image.

## Managing the stack

```bash
whistor start          # Start all containers
whistor stop           # Stop all containers
whistor restart        # Restart all containers
whistor status         # Show container state + .onion address
whistor logs           # Follow live logs (Ctrl+C to exit)
whistor update         # Pull configured Docker images and restart
whistor onion          # Print the .onion address and homeserver URL
```

---

## Web administration from your PC

The `admin` Docker service serves [Ketesa](https://github.com/etkecc/ketesa), the
maintained Synapse administration UI, on **port 8080**. Use it to list, search,
create and edit users, reset passwords, manage administrator rights and deactivate
accounts. The browser calls Synapse through the same service: no Docker hostname
or `.onion` connectivity is required on your PC. Synapse checks administrator
permissions on each management API request.

### Install or upgrade

On the **server**, update the checkout and start the stack:

```bash
cd /path/to/Whistor
git pull --ff-only
docker compose up -d --build
whistor user admin YOUR_ADMIN_USERNAME
```

The last command creates your first administrator and prompts for a password;
skip it if an administrator already exists. Keep an existing working admin account.
The interface uses Matrix administrator credentials, not your SSH/Linux login.

### LAN (no VPN required)

On your **PC**, open `http://SERVER_LAN_IP:8080` and sign in with the administrator
account. The homeserver URL is configured automatically. The UI listens on all
IPv4 interfaces by default. Allow TCP 8080 from your LAN in the server firewall if
needed. You do not need a browser installed on the server.

### Tailscale

Install Tailscale on both the server and your PC and join the same tailnet. Open
`http://SERVER_TAILSCALE_IP:8080` from your PC. No public port forwarding is needed;
your tailnet policy must allow your PC to reach server TCP 8080.

For a private HTTPS URL, run on the server:

```bash
tailscale serve --bg http://127.0.0.1:8080
```

Open the HTTPS URL printed by Tailscale from your PC. Tailscale may first ask you
to enable Serve/HTTPS for the tailnet. This uses **Serve**, not public Funnel.

### SSH tunnel

From your **PC**, keep this running:

```bash
ssh -N -L 8080:127.0.0.1:8080 USER@SERVER
```

Then open `http://localhost:8080`. If local port 8080 is occupied, forward another
local port, for example `-L 18080:127.0.0.1:8080`, and open `http://localhost:18080`.

### Bind address, custom port and Internet access

Create `.env` next to `docker-compose.yml` (or copy `.env.example`):

```dotenv
WHISTOR_ADMIN_BIND=0.0.0.0
WHISTOR_ADMIN_PORT=8080
```

Set the bind address to the server's LAN/Tailscale IPv4 to select one interface,
or to `127.0.0.1` for SSH/Tailscale Serve/reverse proxy access only. Apply changes
with `docker compose up -d --build admin`. The UI accepts LAN IPs, DNS names and
Tailscale names; the Matrix service itself still has no published host port.

For access from the Internet without a VPN, point an **HTTPS reverse proxy** at
`http://127.0.0.1:8080`, preserving `Host` and setting `X-Forwarded-Proto: https`.
Use a dedicated hostname at `/` (subpaths are not supported). Use HTTPS when
sending administrator credentials over untrusted networks; do not port-forward
plain HTTP 8080 directly to the Internet. Log out after administration, especially
on a shared PC. The web UI does not need the Docker socket or Synapse data volumes.

Run `whistor admin` to display access options. `whistor update` pulls the Synapse
and Tor images and rebuilds the administration image with the latest upstream UI.
For installations made without Git, rerun the installer to retrieve new project files.

## Creating users

Public registration is disabled. Accounts are created by an admin on the host machine.

```bash
# Create a regular user (interactive password prompt)
whistor user add USERNAME

# Create a regular user (inline password)
whistor user add USERNAME PASSWORD

# Create an admin user
whistor user admin USERNAME PASSWORD

# List all users
whistor user list

# Deactivate a user (data preserved)
whistor user delete USERNAME

# Change a user's password
whistor user passwd USERNAME
```

A user's full Matrix ID is: `@USERNAME:your-address.onion`

---

## Client setup

> [!NOTE]
> **Mobile (Android / iOS) — Recommended ✅**
> Element on mobile works perfectly with whistor out of the box.
> All features are functional: E2EE, device verification, notifications, file sharing.

> [!WARNING]
> **Desktop (Linux / macOS / Windows) — Use with caution ⚠️**
> Desktop clients require manual proxy configuration to route traffic through Tor.
> Some features may not work correctly depending on the client and configuration used.
> The most reliable desktop approach is **Cinny via Tor Browser** as described below.

All clients connect to whistor via **Tor Browser** using a dedicated persistent profile.
This approach works on every OS, requires no proxy configuration, and keeps your
whistor session completely separate from your regular browsing.

```
Tor Browser (whistor profile) → Tor network → .onion → Synapse
```

The Matrix web client runs directly inside Tor Browser — no desktop app, no proxy
settings to manage. The `.onion` address is resolved natively by Tor Browser.

---

### Desktop (Linux / macOS / Windows)

The recommended approach on all desktop platforms is **Tor Browser** with a cookie
exception for Element Web. This requires no proxy configuration, works natively
with `.onion` addresses, and keeps your Matrix session persistent across restarts.

---

#### Step 1 — Install Tor Browser

**Linux — Flatpak (recommended, works on all distros)**

```bash
flatpak install flathub com.github.micahflee.torbrowser-launcher
```

**Linux — Manual**

```bash
cd ~/Downloads
wget https://www.torproject.org/dist/torbrowser/14.5/tor-browser-linux-x86_64-14.5.tar.xz
tar -xJf tor-browser-linux-x86_64-14.5.tar.xz
cd tor-browser
./start-tor-browser.desktop --register-app
```

**macOS / Windows**

Download and install from the official site:
[https://www.torproject.org/download/](https://www.torproject.org/download/)

---

#### Step 2 — Add a cookie exception for Element Web

By default Tor Browser deletes all cookies and site data on close. Instead of
disabling this globally, add a targeted exception for Element Web only — your
Matrix session will persist while everything else stays amnesic.

In Tor Browser, open:
```
about:preferences#privacy
```

Scroll to **Cookies and Site Data** → click **"Manage Exceptions..."**

Add the following URLs and set them to **Allow**:

```
https://app.element.io
https://app.cinny.in
```

Click **"Save Changes"**.

> Your Tor Browser remains fully amnesic for all other sites.
> Only Element Web and Cinny will retain their session data between restarts.

---

#### Step 3 — Connect to your whistor server

Open one of these Matrix web clients in Tor Browser:

| Client | URL | Style |
|---|---|---|
| Element Web | `https://app.element.io` | Full-featured, recommended |
| Cinny | `https://app.cinny.in` | Discord-style, clean UI |
| Hydrogen | `https://hydrogen.element.io` | Ultra lightweight |

Enter your homeserver when prompted:
```
http://YOUR_ADDRESS.onion:8448
```

Log in with your username and password. Your session will persist across restarts
thanks to the cookie exception set in Step 2.

---

### Android

**1. Install Orbot** (Tor proxy for Android)  
[Play Store](https://play.google.com/store/apps/details?id=org.torproject.android) · [F-Droid](https://guardianproject.info/fdroid/)

**2. Configure Orbot**
- Enable **VPN mode**
- Settings → check **"Start on Boot"**
- VPN apps list → add **Element**
- Tap Start

✅ Orbot starts automatically at boot — zero daily friction after setup.

**3. Install Element**  
[Play Store](https://play.google.com/store/apps/details?id=im.vector.app) · [F-Droid](https://f-droid.org/packages/im.vector.app/)

**4. Connect Element**
- "Sign in" → "Edit" → enter `http://YOUR_ADDRESS.onion:8448`
- Enter your username and password

> Orbot handles the proxy at VPN level — no proxy settings needed inside Element.

---

### iOS

**1. Install Orbot**  
[App Store](https://apps.apple.com/app/orbot/id1609461976)

**2. Configure Orbot**
- Enable **VPN mode**
- ⚠️ On iOS, Orbot must be launched manually before using Element (Apple restricts background VPN processes)

**3. Install Element**  
[App Store](https://apps.apple.com/app/element/id1083446067)

**4. Enable proxy support in Element**
- Settings → **Labs** → enable "Proxy support"
- Set proxy: `SOCKS5` / `127.0.0.1` / `9050`

**5. Connect Element**
- "Sign in" → "Edit" → `http://YOUR_ADDRESS.onion:8448`
- Enter your username and password

> Daily friction: 1 tap to open Orbot before using Element.

---

### Quick reference table

| OS | Method | Client | Daily friction |
|---|---|---|---|
| Android | Orbot VPN mode | Element (native app) | None ✅ |
| iOS | Orbot VPN mode | Element (native app) | 1 tap |
| Linux | Tor Browser + cookie exception | Element Web / Cinny | None ✅ |
| macOS | Tor Browser + cookie exception | Element Web / Cinny | None ✅ |
| Windows | Tor Browser + cookie exception | Element Web / Cinny | None ✅ |

---

## Backup & restore

> ⚠️ The `whistor_tor-data` volume holds the **private keys of your hidden service**.  
> Deleting it means **permanent, unrecoverable loss** of your `.onion` address.

```bash
# Backup using the built-in command
whistor backup
# → saves a timestamped archive to ~/whistor/backups/

# Manual backup (both Tor keys and Synapse data)
docker run --rm \
  -v whistor_tor-data:/tor:ro \
  -v whistor_synapse-data:/synapse:ro \
  -v $(pwd):/backup \
  alpine tar czf /backup/whistor-backup-$(date +%Y%m%d).tar.gz /tor /synapse

# Restore
docker run --rm \
  -v whistor_tor-data:/tor \
  -v whistor_synapse-data:/synapse \
  -v $(pwd):/backup \
  alpine tar xzf /backup/whistor-backup-DATE.tar.gz -C /
```

| Docker volume | Contents |
|---|---|
| `whistor_tor-data` | Tor hidden service private keys + `.onion` hostname — **critical** |
| `whistor_synapse-data` | Synapse database, media store, signing key |

---

## Security

- Synapse uses an `internal: true` Docker network with no outbound Internet routing. Tor and the administration proxy also have their own access networks.
- Only the administration service publishes a port (8080 by default, configurable for LAN/Tailscale). Synapse has no published port.
- Matrix federation is disabled via `federation_domain_whitelist: []` and `trusted_key_servers: []`
- Public registration is disabled — only admins can create accounts
- All secrets (registration key, macaroon key, form secret) are randomly generated on first boot and stored only inside the Docker volume
- Enable **E2EE (end-to-end encryption)** in your Matrix rooms — even the server cannot read encrypted messages

---

## Project structure

```
whistor/
├── docker-compose.yml              # Stack definition (Synapse + Tor)
├── install.sh                      # One-liner installer
├── whistor                         # CLI management tool
├── whistor.config                  # Generated on first boot — client config
├── config/
│   ├── torrc.template              # Tor daemon configuration
│   └── homeserver.template.yaml   # Synapse configuration template
└── scripts/
    └── entrypoint.sh               # Container init + Synapse startup script
```

---

## License

MIT

## Maintaining the documentation

The English documentation sources are in `docs-src/`. GitHub Pages serves the
compiled static site from `main` → `/docs`, including navigation and search.
After editing the sources, rebuild and commit the generated `docs/` files:

```bash
python3 -m venv .venv-docs
.venv-docs/bin/pip install -r requirements-docs.txt
.venv-docs/bin/python scripts/build-docs.py
git add docs-src docs mkdocs.yml
```

GitHub Pages publishes changes pushed to `main` automatically. The documentation
workflow checks the MkDocs build on pull requests and source updates.
