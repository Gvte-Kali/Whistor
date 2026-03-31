#!/bin/bash
# =============================================================================
# install.sh — whistor one-liner installer
# =============================================================================
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Gvte-Kali/whistor/main/install.sh | bash
#
# What this script does, in order:
#   1. Check that Docker and Docker Compose are installed and running
#   2. Clone the whistor repository (or fetch files individually if git is absent)
#   3. Install the `whistor` CLI command into /usr/local/bin
#   4. Start the Docker Compose stack (Synapse + Tor containers)
#   5. Wait for Tor to generate the hidden service .onion address
#   6. Extract the registration shared secret from the running Synapse config
#   7. Generate the whistor.config file on the host with all client parameters
#   8. Print a summary in the terminal
#
# Environment variables you can override before running:
#   WHISTOR_DIR   — where to install the project (default: $HOME/whistor)
#
# =============================================================================

# Exit immediately on error, treat unset variables as errors,
# and propagate pipe failures correctly.
set -euo pipefail

# =============================================================================
# CONFIGURATION — Edit these before pushing to GitHub
# =============================================================================

# GitHub repository URL (used by git clone)
REPO_URL="https://github.com/Gvte-Kali/whistor"

# Raw base URL (used as fallback when git is not available)
RAW_URL="https://raw.githubusercontent.com/Gvte-Kali/whistor/main"

# Installation directory on the host machine.
# Can be overridden by setting WHISTOR_DIR before running the script.
INSTALL_DIR="${WHISTOR_DIR:-$HOME/whistor}"

# Path where the client configuration file will be written after first boot.
CONFIG_OUTPUT="${INSTALL_DIR}/whistor.config"

# =============================================================================
# TERMINAL COLORS AND LOGGING HELPERS
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'   # No Color — resets all attributes

# Logging helpers: each writes a prefixed, colored line to stdout (or stderr for errors).
log()     { echo -e "${CYAN}[whistor]${NC} $*"; }
ok()      { echo -e "${GREEN}[✔]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✘] ERROR:${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

# section() prints a bold blue separator header for each major step.
section() { echo -e "\n${BOLD}${BLUE}── $* ${NC}"; }

# =============================================================================
# BANNER
# =============================================================================

echo -e "${BOLD}${MAGENTA}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════════════╗
  ║              w h i s t o r                       ║
  ║      Matrix homeserver over Tor hidden service    ║
  ╚═══════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# =============================================================================
# STEP 1 — DEPENDENCY CHECKS
# =============================================================================
# We need Docker, a running Docker daemon, Docker Compose (v1 or v2),
# and at least one of curl or wget to fetch files.
# =============================================================================
section "Checking dependencies"

# ── Docker binary ──────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  die "Docker is not installed.\n  → Install it from: https://docs.docker.com/get-docker/"
fi

# ── Docker daemon ──────────────────────────────────────────────────────────
# `docker info` fails if the daemon is not running.
if ! docker info &>/dev/null 2>&1; then
  die "Docker daemon is not running.\n  → Start it with: sudo systemctl start docker"
fi
ok "Docker: $(docker --version)"

# ── Docker Compose ─────────────────────────────────────────────────────────
# Docker Compose v2 ships as a CLI plugin (`docker compose`).
# Docker Compose v1 is a standalone binary (`docker-compose`).
# We detect which one is available and store the command in COMPOSE_CMD.
if docker compose version &>/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
  ok "Docker Compose (plugin): $(docker compose version)"
elif command -v docker-compose &>/dev/null; then
  COMPOSE_CMD="docker-compose"
  ok "Docker Compose (standalone): $(docker-compose --version)"
else
  die "Docker Compose is not installed.\n  → Install it from: https://docs.docker.com/compose/install/"
fi

# ── curl or wget ────────────────────────────────────────────────────────────
# We need one of these to fetch individual files in the fallback path
# when git is not available.
if command -v curl &>/dev/null; then
  FETCH_CMD="curl -fsSL"
  ok "curl is available"
elif command -v wget &>/dev/null; then
  FETCH_CMD="wget -qO-"
  ok "wget is available"
else
  die "Neither curl nor wget was found. Please install one of them."
fi

# ── qrencode ────────────────────────────────────────────────────────────────
# Required by `whistor user qr` to print QR codes in the terminal.
if ! command -v qrencode &>/dev/null; then
  log "Installing qrencode..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq qrencode
  elif command -v brew &>/dev/null; then
    brew install qrencode
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y qrencode
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm qrencode
  else
    warn "Could not install qrencode automatically — package manager not recognized."
    warn "Install it manually, then re-run: whistor user qr <username>"
  fi
fi
command -v qrencode &>/dev/null && ok "qrencode: $(qrencode --version 2>&1 | head -1)"

# =============================================================================
# STEP 2 — DOWNLOAD / CLONE REPOSITORY
# =============================================================================
# Preferred path: clone with git (gets all files in one shot, enables updates).
# Fallback path:  fetch each file individually via curl/wget.
# =============================================================================
section "Downloading project files"

# Create the directory structure regardless of which download method we use.
mkdir -p "$INSTALL_DIR"/{config,scripts}

if command -v git &>/dev/null; then
  # git is available — use it.
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    # The repo already exists locally; just pull the latest changes.
    warn "Existing repository found — pulling latest changes..."
    git -C "$INSTALL_DIR" pull --ff-only
  else
    # Fresh clone into the install directory.
    log "Cloning $REPO_URL into $INSTALL_DIR..."
    git clone "$REPO_URL" "$INSTALL_DIR"
  fi
else
  # git is not available — fetch each file individually.
  log "git not found — fetching files one by one..."

  # Helper: download a single file from the raw GitHub URL.
  # Arguments:
  #   $1 — path relative to the repo root (used to build the remote URL)
  #   $2 — destination path relative to INSTALL_DIR
  fetch_file() {
    local remote_path="$1"
    local local_path="$2"
    log "  ↓ $local_path"
    $FETCH_CMD "${RAW_URL}/${remote_path}" > "${INSTALL_DIR}/${local_path}"
  }

  fetch_file "docker-compose.yml"              "docker-compose.yml"
  fetch_file "config/torrc.template"           "config/torrc.template"
  fetch_file "config/homeserver.template.yaml" "config/homeserver.template.yaml"
  fetch_file "scripts/entrypoint.sh"           "scripts/entrypoint.sh"
  fetch_file "whistor"                         "whistor"
fi

# Ensure all shell scripts are executable.
chmod +x "$INSTALL_DIR/scripts/entrypoint.sh"
ok "Project files are ready in $INSTALL_DIR"

# =============================================================================
# STEP 3 — INSTALL THE whistor CLI COMMAND
# =============================================================================
# We copy the `whistor` script into /usr/local/bin so it is available
# system-wide without needing to prefix it with a path.
#
# We first patch the script so its INSTALL_DIR default points to the actual
# installation path chosen by this run, instead of the generic $HOME/whistor.
# =============================================================================
section "Installing the whistor CLI command"

WHISTOR_BIN="${INSTALL_DIR}/whistor"
WHISTOR_DEST="/usr/local/bin/whistor"

if [[ -f "$WHISTOR_BIN" ]]; then
  chmod +x "$WHISTOR_BIN"

  # Patch the default INSTALL_DIR inside the whistor script so that it
  # resolves to the directory we actually installed into.
  # This sed call replaces the fallback value in the WHISTOR_DIR variable.
  sed -i "s|WHISTOR_DIR:-\$HOME/whistor|WHISTOR_DIR:-${INSTALL_DIR}|g" \
    "$WHISTOR_BIN" 2>/dev/null || true

  # Try to install to /usr/local/bin — first with passwordless sudo,
  # then by checking write permission directly, then fall back gracefully.
  if sudo -n true 2>/dev/null; then
    # sudo is available without a password prompt (e.g. in CI or root session).
    sudo cp "$WHISTOR_BIN" "$WHISTOR_DEST"
    sudo chmod +x "$WHISTOR_DEST"
    ok "CLI installed: $WHISTOR_DEST"
  elif [[ -w "/usr/local/bin" ]]; then
    # Current user already has write access to /usr/local/bin.
    cp "$WHISTOR_BIN" "$WHISTOR_DEST"
    chmod +x "$WHISTOR_DEST"
    ok "CLI installed: $WHISTOR_DEST"
  else
    # No write access — inform the user and add a temporary PATH fallback
    # so the command still works for the duration of this shell session.
    warn "Insufficient permissions to write to /usr/local/bin."
    warn "To install manually, run:"
    warn "  sudo cp ${WHISTOR_BIN} /usr/local/bin/whistor"
    warn "  sudo chmod +x /usr/local/bin/whistor"
    # Temporarily prepend the install dir to PATH so `whistor` resolves now.
    export PATH="${INSTALL_DIR}:$PATH"
    ok "CLI available in this session via PATH (temporary)."
  fi
else
  warn "whistor script not found in ${INSTALL_DIR} — CLI install skipped."
fi

# =============================================================================
# STEP 4 — START THE DOCKER COMPOSE STACK
# =============================================================================
# This brings up two containers:
#   - whistor-tor-daemon  : Tor daemon that creates the hidden service
#   - synapse-server      : Matrix Synapse homeserver
#
# The Synapse container runs our custom entrypoint.sh on first boot,
# which waits for Tor, reads the .onion address, and generates the config.
# =============================================================================
section "Starting the Docker stack"

# Move into the install directory so docker compose finds the compose file.
cd "$INSTALL_DIR"

$COMPOSE_CMD up -d
ok "Stack started"

# =============================================================================
# STEP 5 — WAIT FOR THE .ONION ADDRESS
# =============================================================================
# Tor needs a few seconds to bootstrap and generate the hidden service key pair.
# The resulting .onion hostname is written to:
#   /var/lib/tor/hidden_service/hostname  (inside the Tor container)
#
# We poll this file every 2 seconds for up to 120 seconds total.
# =============================================================================
section "Waiting for the .onion address"

log "Polling Tor for the hidden service hostname (up to 120s)..."

ONION_ADDRESS=""
for i in $(seq 1 60); do
  # Try to read the hostname file from inside the Tor container.
  # Suppress all errors — the file won't exist during the first few seconds.
  ONION=$(docker exec whistor-tor-daemon \
    cat /var/lib/tor/hidden_service/synapse/hostname 2>/dev/null \
    | tr -d '[:space:]' || true)

  # Validate: non-empty and ends with .onion (basic sanity check).
  if [[ -n "$ONION" && "$ONION" == *.onion ]]; then
    ONION_ADDRESS="$ONION"
    break
  fi

  # Show a progress indicator on the same line while waiting.
  printf "\r  ${DIM}Attempt %d/60 — waiting...${NC}" "$i"
  sleep 2
done
echo ""   # Move to a new line after the progress indicator.

# Handle the case where Tor never produced a hostname.
if [[ -z "$ONION_ADDRESS" ]]; then
  warn ".onion address is not available yet."
  warn "The config file will be incomplete. Re-run: whistor config"
  # Use a placeholder so the rest of the script can still write the config.
  ONION_ADDRESS="ONION_ADDRESS_NOT_YET_AVAILABLE"
else
  ok ".onion address: ${BOLD}${ONION_ADDRESS}${NC}"
fi

# =============================================================================
# STEP 6 — RETRIEVE THE REGISTRATION SHARED SECRET
# =============================================================================
# The registration_shared_secret is generated randomly by entrypoint.sh
# on first boot and written into /data/homeserver.yaml inside the Synapse
# container. We extract it here so we can include it in the config file.
#
# We poll for up to 60 seconds because Synapse may still be initialising.
# =============================================================================

REGISTRATION_SECRET=""
for i in $(seq 1 30); do
  SECRET=$(docker exec synapse-server \
    grep -oP '(?<=registration_shared_secret: ).*' /data/homeserver.yaml \
    2>/dev/null | tr -d '"' || true)

  if [[ -n "$SECRET" ]]; then
    REGISTRATION_SECRET="$SECRET"
    break
  fi
  sleep 2
done

# Provide a fallback message if Synapse hasn't written the config yet.
if [[ -z "$REGISTRATION_SECRET" ]]; then
  REGISTRATION_SECRET="(retrieve with: docker exec synapse-server grep registration_shared_secret /data/homeserver.yaml)"
fi

# =============================================================================
# STEP 7 — GENERATE whistor.config ON THE HOST
# =============================================================================
# This plain-text file is the single source of truth for anyone who needs
# to connect a Matrix client to this server. It contains:
#   - The .onion address
#   - Universal connection parameters
#   - Per-platform client setup instructions (Android, iOS, Linux, macOS, Windows)
#   - Admin commands
#   - Backup/restore instructions
#
# The file is chmod 600 because it contains the registration shared secret.
# =============================================================================
section "Generating client configuration file"

# Capture metadata for the file header.
GENERATED_AT=$(date '+%Y-%m-%d %H:%M:%S %Z')
HOST_OS=$(uname -s)
HOST_ARCH=$(uname -m)

cat > "$CONFIG_OUTPUT" << CONFIGEOF
################################################################################
##                                                                            ##
##                          W H I S T O R                                    ##
##                    Client Configuration File                               ##
##                                                                            ##
##  Generated : ${GENERATED_AT}
##  Host      : $(hostname) (${HOST_OS} ${HOST_ARCH})
##  Directory : ${INSTALL_DIR}
##                                                                            ##
##  ⚠  This file contains secrets — do NOT share it publicly.               ##
##                                                                            ##
################################################################################


╔══════════════════════════════════════════════════════════════════════════════╗
║                          YOUR SERVER ADDRESS                                ║
╚══════════════════════════════════════════════════════════════════════════════╝

  Homeserver (Matrix server name) : ${ONION_ADDRESS}
  Client connection URL           : http://${ONION_ADDRESS}:8448

  ⚠  This address is ONLY reachable over Tor.
     Your Matrix client MUST route traffic through a local Tor SOCKS5 proxy.


╔══════════════════════════════════════════════════════════════════════════════╗
║                    UNIVERSAL CONNECTION PARAMETERS                          ║
╚══════════════════════════════════════════════════════════════════════════════╝

  ┌─────────────────────────────────────────────────────────────┐
  │  Homeserver URL   : http://${ONION_ADDRESS}:8448
  │  Server name      : ${ONION_ADDRESS}
  │  Proxy type       : SOCKS5
  │  Proxy host       : 127.0.0.1
  │  Proxy port       : see per-OS section below
  │  TLS/SSL          : NO  (Tor encrypts the transport natively)
  │  Federation       : DISABLED (isolated private server)
  └─────────────────────────────────────────────────────────────┘

  → Accounts must be created by an admin using the commands below.
    Public registration is disabled by default.


╔══════════════════════════════════════════════════════════════════════════════╗
║                            ADMIN COMMANDS                                   ║
╚══════════════════════════════════════════════════════════════════════════════╝

  # Create a regular user
  whistor user add USERNAME PASSWORD

  # Create an admin user
  whistor user admin USERNAME PASSWORD

  # List all users
  whistor user list

  # Deactivate a user
  whistor user delete USERNAME

  # Change a password
  whistor user passwd USERNAME

  # View live logs
  whistor logs

  # Stop the server
  whistor stop

  # Registration shared secret (for API calls)
  ${REGISTRATION_SECRET}


╔══════════════════════════════════════════════════════════════════════════════╗
║                  CLIENT SETUP — PER PLATFORM                                ║
╚══════════════════════════════════════════════════════════════════════════════╝


Look at the github page https://github.com/Gvte-Kali/Whistor


╔══════════════════════════════════════════════════════════════════════════════╗
║                           QUICK REFERENCE TABLE                             ║
╚══════════════════════════════════════════════════════════════════════════════╝

  Platform  │ Matrix Client    │ Tor method              │ Port  │ Daily friction
  ──────────┼──────────────────┼─────────────────────────┼───────┼───────────────
  Android   │ Element          │ Orbot (VPN + boot)      │ 9050  │ None ✅
  iOS       │ Element          │ Orbot (VPN mode)        │ 9050  │ 1 tap
  Linux     │ Element / Nheko  │ tor daemon (systemd)    │ 9050  │ None ✅
  macOS     │ Element          │ brew install tor        │ 9050  │ None ✅
  macOS     │ Element          │ Tor Browser             │ 9150  │ Manual launch
  Windows   │ Element          │ Tor Expert Bundle (svc) │ 9050  │ None ✅
  Windows   │ Element          │ Tor Browser             │ 9150  │ Manual launch
  ──────────┴──────────────────┴─────────────────────────┴───────┴───────────────

  Homeserver URL to enter in ALL clients:
  → http://${ONION_ADDRESS}:8448


╔══════════════════════════════════════════════════════════════════════════════╗
║                            BACKUP & RESTORE                                 ║
╚══════════════════════════════════════════════════════════════════════════════╝

  ⚠  The tor-data volume holds the PRIVATE KEYS of your hidden service.
     Deleting it means PERMANENT loss of your .onion address.

  # Backup (both Tor keys and Synapse data)
  docker run --rm \\
    -v whistor_tor-data:/tor \\
    -v whistor_synapse-data:/synapse \\
    -v \$(pwd):/backup \\
    alpine tar czf /backup/whistor-backup-\$(date +%Y%m%d).tar.gz /tor /synapse

  # Or use the built-in command:
  whistor backup

  # Restore
  docker run --rm \\
    -v whistor_tor-data:/tor \\
    -v whistor_synapse-data:/synapse \\
    -v \$(pwd):/backup \\
    alpine tar xzf /backup/whistor-backup-DATE.tar.gz -C /


╔══════════════════════════════════════════════════════════════════════════════╗
║                              SECURITY NOTES                                 ║
╚══════════════════════════════════════════════════════════════════════════════╝

  • The Docker network is marked internal:true — containers have no outbound
    internet access. Tor is the only way in or out.

  • No ports are published on the host machine's network interface.

  • Matrix federation is disabled: users can only communicate with other users
    on THIS server. matrix.org and other servers are unreachable by design.

  • Public registration is disabled. Only admins can create accounts.

  • All secrets (registration key, macaroon key, form secret) are randomly
    generated on first boot and never leave the server.

  • Enable E2EE (end-to-end encryption) in your Matrix rooms for maximum
    confidentiality — even the server cannot read encrypted messages.

  • To update Synapse:
      cd ${INSTALL_DIR} && whistor update

################################################################################
##  End of configuration file — whistor                                      ##
################################################################################
CONFIGEOF

# Restrict file permissions: readable only by the owner (contains secrets).
chmod 600 "$CONFIG_OUTPUT"
ok "Configuration file written: ${BOLD}${CONFIG_OUTPUT}${NC}"

# =============================================================================
# STEP 8 — PRINT TERMINAL SUMMARY
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════════════════════════╗"
echo "  ║           Deployment completed successfully!                 ║"
echo "  ╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "  ${BOLD}Your server address${NC}"
echo -e "  ${CYAN}http://${ONION_ADDRESS}:8448${NC}"
echo -e "  ${DIM}(only reachable via Tor)${NC}"
echo ""

echo -e "${BOLD}${BLUE}── Step 1 — Create your admin account ${NC}"
echo ""
echo -e "  Run this command to create your first admin user:"
echo -e "  ${CYAN}whistor user admin USERNAME PASSWORD${NC}"
echo ""

echo -e "${BOLD}${BLUE}── Step 2 — Install a Matrix client ${NC}"
echo ""
echo -e "  Recommended: ${BOLD}Element${NC}"
echo -e "  • Android / iOS : search \"Element\" in your app store"
echo -e "  • Desktop       : https://element.io/download"
echo -e "  • Web           : https://app.element.io"
echo ""

echo -e "${BOLD}${BLUE}── Step 3 — Route traffic through Tor ${NC}"
echo ""
echo -e "  Your server is a Tor hidden service — your client MUST use Tor."
echo ""
echo -e "  ${BOLD}Android / iOS${NC}"
echo -e "  • Install ${CYAN}Orbot${NC} and enable VPN mode"
echo -e "  • Add Element to the Orbot VPN app list"
echo ""
echo -e "  ${BOLD}Linux${NC}"
echo -e "  • ${CYAN}sudo apt install tor && sudo systemctl enable --now tor${NC}"
echo -e "  • In Element: Settings → General → Proxy → SOCKS5 / 127.0.0.1 / 9050"
echo ""
echo -e "  ${BOLD}macOS${NC}"
echo -e "  • ${CYAN}brew install tor && brew services start tor${NC}"
echo -e "  • In Element: Settings → General → Proxy → SOCKS5 / 127.0.0.1 / 9050"
echo ""
echo -e "  ${BOLD}Windows${NC}"
echo -e "  • Download Tor Browser from https://www.torproject.org/download/"
echo -e "  • Keep it running, then in Element: Proxy → SOCKS5 / 127.0.0.1 / 9150"
echo ""

echo -e "${BOLD}${BLUE}── Step 4 — Connect Element to your server ${NC}"
echo ""
echo -e "  1. Open Element → \"Sign in\" → \"Edit\" (homeserver field)"
echo -e "  2. Enter your homeserver URL:"
echo -e "     ${BOLD}${CYAN}http://${ONION_ADDRESS}:8448${NC}"
echo -e "  3. Log in with the credentials you created in Step 1"
echo ""

echo -e "${BOLD}${BLUE}── Useful commands ${NC}"
echo ""
echo -e "  ${CYAN}whistor status${NC}              Check containers and server address"
echo -e "  ${CYAN}whistor user list${NC}           List all registered users"
echo -e "  ${CYAN}whistor user add USER PASS${NC}  Create a regular user"
echo -e "  ${CYAN}whistor logs${NC}                Follow live server logs"
echo -e "  ${CYAN}whistor backup${NC}              Backup Tor keys + Synapse data"
echo -e "  ${CYAN}whistor help${NC}                Show all available commands"
echo ""
echo -e "  ${DIM}Full client config: cat ${CONFIG_OUTPUT}${NC}"
echo ""
