# whistor

> A self-hosted Matrix (Synapse) homeserver exposed **exclusively** over a Tor v3 hidden service.  
> No open ports. No DNS. No clearnet exposure. One command to deploy.

---

## Table of Contents

- [How it works](#how-it-works)
- [Server requirements](#server-requirements)
- [Install the server](#install-the-server)
- [Managing the stack](#managing-the-stack)
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
  │   Synapse        │  ← container: matrixdotorg/synapse
  │   homeserver     │
  └──────────────────┘
```

- Synapse **never** binds to the host machine's network interface
- Tor is the **only** ingress — no clearnet access possible
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

## Managing the stack

```bash
whistor start          # Start all containers
whistor stop           # Stop all containers
whistor restart        # Restart all containers
whistor status         # Show container state + .onion address
whistor logs           # Follow live logs (Ctrl+C to exit)
whistor update         # Pull latest Docker images and restart
whistor onion          # Print the .onion address and homeserver URL
```

---

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

All clients connect to whistor via **Tor Browser**.
This approach works on every OS, requires no configuration.

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

- The Docker network is marked `internal: true` — containers have no outbound internet access
- No ports are published to the host machine's network interface in `docker-compose.yml`
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
