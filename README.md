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

All clients connect to whistor via **Tor Browser** using a dedicated persistent profile.
This approach works on every OS, requires no proxy configuration, and keeps your
whistor session completely separate from your regular browsing.

```
Tor Browser (whistor profile) → Tor network → .onion → Synapse
```

The Matrix web client runs directly inside Tor Browser — no desktop app, no proxy
settings to manage. The `.onion` address is resolved natively by Tor Browser.

---

### Tor Browser setup (all desktop platforms)

This setup is done **once**. After that, opening your whistor profile is a single click.

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

#### Step 2 — Create a dedicated whistor profile

Open the Tor Browser profile manager:

```bash
# Linux — Flatpak
flatpak run com.github.micahflee.torbrowser-launcher --ProfileManager

# Linux — Manual install
~/tor-browser/Browser/firefox --ProfileManager

# macOS
/Applications/Tor\ Browser.app/Contents/MacOS/firefox --ProfileManager

# Windows (run in terminal)
"C:\Users\YOU\Desktop\Tor Browser\Browser\firefox.exe" --ProfileManager
```

In the profile manager:
- Click **"Create Profile"**
- Name it `whistor`
- Click **"Finish"**
- Select the `whistor` profile
- **Uncheck** "Use the selected profile without asking at startup" — this keeps
  your default profile intact for regular Tor browsing
- Click **"Start Tor Browser"**

---

#### Step 3 — Enable persistent history and cookies in the whistor profile

By default Tor Browser deletes everything on close. In your `whistor` profile only,
enable persistence so your Matrix session survives restarts.

In the Tor Browser address bar, go to:
```
about:preferences#privacy
```

Under **History**:
- Change `Firefox will:` from **"Never remember history"** to **"Remember history"**

This single change enables both history and cookie persistence. Your login session,
encryption keys, and room state will be saved between sessions.

> Your default Tor Browser profile is not affected — it stays fully amnesic.

---

#### Step 4 — Open the Matrix web client

In your `whistor` profile, navigate to one of these Matrix web clients:

| Client | URL | Style |
|---|---|---|
| Element Web | `https://app.element.io` | Full-featured, recommended |
| Cinny | `https://app.cinny.in` | Discord-style, clean UI |
| Hydrogen | `https://hydrogen.element.io` | Ultra lightweight |

Enter your homeserver when prompted:
```
http://YOUR_ADDRESS.onion:8448
```

Log in with your username and password. Your session will persist across restarts.

---

#### Step 5 — Launch the whistor profile directly (shortcut)

To open Tor Browser directly on the whistor profile without going through the
profile manager every time:

```bash
# Linux — Flatpak
flatpak run com.github.micahflee.torbrowser-launcher -P whistor

# Linux — Manual
~/tor-browser/Browser/firefox -P whistor

# macOS
/Applications/Tor\ Browser.app/Contents/MacOS/firefox -P whistor

# Windows
"C:\Users\YOU\Desktop\Tor Browser\Browser\firefox.exe" -P whistor
```

Create a permanent alias on Linux/macOS:

```bash
echo "alias whistor-browser='flatpak run com.github.micahflee.torbrowser-launcher -P whistor'" >> ~/.bashrc
source ~/.bashrc
```

Type `whistor-browser` in any terminal to launch directly into your whistor session.

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

Follow the **Tor Browser setup** section above — it covers Linux in full detail.

If you prefer a native desktop app, install the Tor daemon and use Element Desktop:

**1. Install and configure the Tor daemon**

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

The default `/etc/tor/torrc` on some distributions tries to bind a DNS listener
on port 5353 (a privileged port), which causes Tor to fail at startup.
Edit the config to disable it:

```bash
sudo nano /etc/tor/torrc
```

Comment out or remove these lines if present:

```
# DNSPort 127.0.0.1:5353
# TransPort 127.0.0.1:9040
```

Make sure this line is present and uncommented:

```
SocksPort 9050
```

Restart and verify:

```bash
sudo systemctl restart tor
sudo systemctl status tor
```

**2. Install Element Desktop via Flatpak**

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub im.riot.Riot
```

**3. Route Element through Tor via Flatpak override**

```bash
flatpak override --user --env=ALL_PROXY=socks5h://127.0.0.1:9050 im.riot.Riot
```

**4. Connect**
- Settings → General → Proxy → `SOCKS5` / `127.0.0.1` / `9050`
- "Sign in" → "Edit" → `http://YOUR_ADDRESS.onion:8448`

---

### macOS

Follow the **Tor Browser setup** section above.

Alternative with a native Tor daemon:

```bash
brew install tor
brew services start tor   # Starts automatically at login — port 9050
```

Then install Element Desktop from [https://element.io/download](https://element.io/download)
and set proxy to `SOCKS5 / 127.0.0.1 / 9050`.

---

### Windows

Follow the **Tor Browser setup** section above.

Alternative with Tor as a Windows service:

- Download **Tor Expert Bundle**: [https://www.torproject.org/download/tor/](https://www.torproject.org/download/tor/)
- Extract to `C:\tor`, open an admin terminal:

```powershell
cd C:\tor
.\tor.exe --service install
net start tor
```

Then install Element Desktop from [https://element.io/download](https://element.io/download)
and set proxy to `SOCKS5 / 127.0.0.1 / 9050`.

---

### Quick reference table

| OS | Method | Client | Daily friction |
|---|---|---|---|
| Android | Orbot VPN mode | Element (native app) | None ✅ |
| iOS | Orbot VPN mode | Element (native app) | 1 tap |
| Linux | Tor Browser — whistor profile | Element Web / Cinny | None ✅ |
| macOS | Tor Browser — whistor profile | Element Web / Cinny | None ✅ |
| Windows | Tor Browser — whistor profile | Element Web / Cinny | None ✅ |

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
