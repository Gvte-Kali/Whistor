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
  - [Linux](#linux)
  - [macOS](#macos)
  - [Windows](#windows)
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

All clients need to **route their traffic through Tor** to reach the `.onion` address.  
Tor acts as a local SOCKS5 proxy — the Matrix client connects to it, Tor does the rest.

```
Matrix client → SOCKS5 127.0.0.1:PORT → Tor network → .onion → Synapse
```

**Parameters to enter in every client:**

| Parameter | Value |
|---|---|
| Homeserver URL | `http://YOUR_ADDRESS.onion:8448` |
| Proxy type | SOCKS5 |
| Proxy host | `127.0.0.1` |
| Proxy port | see per-OS section below |
| TLS/SSL | No (Tor encrypts the transport natively) |

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

### Linux

**1. Install the Tor daemon**

```bash
# Debian / Ubuntu
sudo apt install tor

# Arch Linux
sudo pacman -S tor

# Fedora
sudo dnf install tor

# Enable automatic startup
sudo systemctl enable --now tor
```

Tor exposes a SOCKS5 proxy on `127.0.0.1:9050`, runs in the background, and starts at boot. ✅ Zero daily friction.

**2. Install Element Desktop**

```bash
# Flatpak (recommended, works on all distros)
flatpak install flathub im.riot.Riot

# Snap
snap install element-desktop

# AppImage / .deb
# https://element.io/download
```

**3. Configure proxy in Element**
- Settings → General → **Proxy**
- `SOCKS5` / `127.0.0.1` / `9050`

**4. Connect**
- "Sign in" → "Edit" → `http://YOUR_ADDRESS.onion:8448`

> Alternative — launch any client via environment variable (no proxy config needed in the app):
> ```bash
> ALL_PROXY=socks5h://127.0.0.1:9050 element-desktop
> ALL_PROXY=socks5h://127.0.0.1:9050 nheko
> ALL_PROXY=socks5h://127.0.0.1:9050 gomuks
> ```

---

### macOS

**Option A — Homebrew (recommended)**

```bash
brew install tor
brew services start tor   # Starts automatically at login
```

Proxy port: **9050** · ✅ Zero daily friction.

**Option B — Tor Browser**  
[Download Tor Browser](https://www.torproject.org/download/) — keep it open while using Element.  
Proxy port: **9150** · ⚠️ Must be launched manually each session.

**Install Element Desktop**  
[Download for macOS](https://element.io/download)

**Configure proxy in Element**
- Settings → General → **Proxy**
- `SOCKS5` / `127.0.0.1` / `9050` (Homebrew) or `9150` (Tor Browser)

**Connect**
- "Sign in" → "Edit" → `http://YOUR_ADDRESS.onion:8448`

---

### Windows

**Option A — Tor Expert Bundle as a Windows service (recommended)**

- Download **Tor Expert Bundle**: [https://www.torproject.org/download/tor/](https://www.torproject.org/download/tor/)
- Extract to `C:\tor`
- Open a terminal **as Administrator**:

```powershell
cd C:\tor
.\tor.exe --service install
net start tor
```

Tor runs as a Windows service and starts automatically at boot. ✅ Zero daily friction.  
Proxy port: **9050**

**Option B — Tor Browser**  
[Download Tor Browser](https://www.torproject.org/download/) — keep it open while using Element.  
Proxy port: **9150** · ⚠️ Must be launched manually each session.

**Install Element Desktop**  
[Download for Windows](https://element.io/download)

**Configure proxy in Element**
- Settings → General → **Proxy**
- `SOCKS5` / `127.0.0.1` / `9050` (service) or `9150` (Tor Browser)

**Connect**
- "Sign in" → "Edit" → `http://YOUR_ADDRESS.onion:8448`

---

### Quick reference table

| OS | Matrix client | Tor method | Port | Daily friction |
|---|---|---|---|---|
| Android | Element | Orbot — VPN mode + Start on Boot | 9050 | None ✅ |
| iOS | Element | Orbot — VPN mode | 9050 | 1 tap |
| Linux | Element / Nheko / Gomuks | `tor` systemd daemon | 9050 | None ✅ |
| macOS | Element | `brew install tor` | 9050 | None ✅ |
| macOS | Element | Tor Browser | 9150 | Manual launch |
| Windows | Element | Tor Expert Bundle (service) | 9050 | None ✅ |
| Windows | Element | Tor Browser | 9150 | Manual launch |

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
