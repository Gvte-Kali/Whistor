#!/bin/bash
# =============================================================================
# .devcontainer/setup.sh — whistor Codespaces post-create setup script
# =============================================================================
#
# This script runs automatically once when the Codespace is first created
# (triggered by the postCreateCommand in devcontainer.json).
#
# It does NOT run install.sh (which is the production one-liner that clones
# the repo from GitHub). Instead it performs a local dev install:
#   1. Installs the `whistor` CLI from the local repo into /usr/local/bin
#   2. Starts the Docker Compose stack using the local files
#   3. Waits for Tor to generate the .onion address
#   4. Creates a default test user automatically
#   5. Prints a summary so you can start testing immediately
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# The workspace root is where GitHub Codespaces clones the repo.
# In Codespaces this is always /workspaces/<repo-name>.
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# We use the repo directory itself as the install directory so that
# docker compose finds docker-compose.yml in the expected location.
INSTALL_DIR="$REPO_DIR"

# Test user created automatically so you can connect a client right away.
TEST_USER="testuser"
TEST_PASS="whistor-test-1234"

# =============================================================================
# TERMINAL COLORS
# =============================================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ok()      { echo -e "${GREEN}[✔]${NC} $*"; }
info()    { echo -e "${CYAN}[→]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
section() { echo -e "\n${BOLD}${CYAN}── $* ${NC}"; }

# =============================================================================
# BANNER
# =============================================================================

echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════════════╗
  ║              w h i s t o r                       ║
  ║         Codespaces dev environment setup          ║
  ╚═══════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# =============================================================================
# STEP 1 — VERIFY DOCKER IS AVAILABLE
# =============================================================================
# Docker-in-Docker takes a few seconds to initialise after the container
# starts. We poll until it responds.
# =============================================================================
section "Waiting for Docker daemon"

for i in $(seq 1 15); do
  if docker info &>/dev/null 2>&1; then
    ok "Docker is ready (attempt $i)"
    break
  fi
  echo -e "  ${DIM}Waiting for Docker... attempt $i/15${NC}"
  sleep 2
done

# Final check — abort if Docker is still not available.
docker info &>/dev/null 2>&1 || {
  echo "Docker daemon did not start in time. Try reopening the Codespace."
  exit 1
}

ok "Docker Compose: $(docker compose version)"

# =============================================================================
# STEP 2 — INSTALL THE whistor CLI
# =============================================================================
# We install the CLI from the local repo files rather than fetching from
# GitHub, so you can test local changes without pushing first.
# =============================================================================
section "Installing the whistor CLI"

WHISTOR_BIN="${REPO_DIR}/whistor"
WHISTOR_DEST="/usr/local/bin/whistor"

if [[ -f "$WHISTOR_BIN" ]]; then
  chmod +x "$WHISTOR_BIN"

  # Patch the default INSTALL_DIR inside the script so it points to
  # the actual repo directory in this Codespace.
  sed -i "s|WHISTOR_DIR:-\$HOME/whistor|WHISTOR_DIR:-${INSTALL_DIR}|g" \
    "$WHISTOR_BIN" 2>/dev/null || true

  cp "$WHISTOR_BIN" "$WHISTOR_DEST"
  chmod +x "$WHISTOR_DEST"
  ok "whistor CLI installed → $WHISTOR_DEST"
else
  echo "whistor script not found at $WHISTOR_BIN"
  exit 1
fi

# =============================================================================
# STEP 3 — START THE DOCKER COMPOSE STACK
# =============================================================================
section "Starting the whistor stack"

cd "$INSTALL_DIR"
docker compose up -d
ok "Stack started"

# =============================================================================
# STEP 4 — WAIT FOR THE .ONION ADDRESS
# =============================================================================
# Tor needs time to bootstrap before the hidden service key is generated.
# We poll the hostname file inside the Tor container.
# =============================================================================
section "Waiting for Tor hidden service"

info "Polling for .onion address (up to 120s)..."

ONION_ADDRESS=""
for i in $(seq 1 60); do
  ONION=$(docker exec whistor-tor-daemon \
    cat /var/lib/tor/hidden_service/hostname 2>/dev/null \
    | tr -d '[:space:]' || true)

  if [[ -n "$ONION" && "$ONION" == *.onion ]]; then
    ONION_ADDRESS="$ONION"
    break
  fi

  printf "\r  ${DIM}Attempt %d/60 — waiting for Tor...${NC}" "$i"
  sleep 2
done
echo ""

if [[ -z "$ONION_ADDRESS" ]]; then
  warn ".onion address not available yet — Tor may still be bootstrapping."
  warn "Run 'whistor onion' in a few seconds to check."
  ONION_ADDRESS="not-yet-available"
else
  ok ".onion address: ${BOLD}${ONION_ADDRESS}${NC}"
fi

# =============================================================================
# STEP 5 — WAIT FOR SYNAPSE TO FINISH INITIALISING
# =============================================================================
# The entrypoint.sh inside the Synapse container also needs a moment to
# generate homeserver.yaml and the signing key on first boot.
# We wait until the Synapse HTTP API responds with a 200.
# =============================================================================
section "Waiting for Synapse to be ready"

info "Polling Synapse health endpoint..."

for i in $(seq 1 30); do
  # /_matrix/client/versions is a lightweight unauthenticated endpoint
  # that returns 200 as soon as Synapse is accepting requests.
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "http://localhost:8008/_matrix/client/versions" 2>/dev/null || echo "000")

  if [[ "$HTTP_STATUS" == "200" ]]; then
    ok "Synapse is ready (HTTP $HTTP_STATUS)"
    break
  fi

  printf "\r  ${DIM}Attempt %d/30 — Synapse returned HTTP %s${NC}" "$i" "$HTTP_STATUS"
  sleep 3
done
echo ""

# =============================================================================
# STEP 6 — CREATE A DEFAULT TEST USER
# =============================================================================
# Create a test account automatically so you can connect a Matrix client
# without running any extra commands.
# =============================================================================
section "Creating default test user"

if docker exec synapse-server \
    register_new_matrix_user \
      -c /data/homeserver.yaml \
      -u "$TEST_USER" \
      -p "$TEST_PASS" \
      --no-admin \
      http://localhost:8008 2>/dev/null; then
  ok "Test user created: @${TEST_USER}:${ONION_ADDRESS}"
else
  # This is non-fatal — the user may already exist if the Codespace was
  # rebuilt without deleting volumes.
  warn "Could not create test user (may already exist — that is fine)."
fi

# =============================================================================
# STEP 7 — WRITE whistor.config
# =============================================================================
# Generate the client configuration file so `whistor config` works.
# =============================================================================
section "Generating whistor.config"

CONFIG_FILE="${INSTALL_DIR}/whistor.config"

cat > "$CONFIG_FILE" << CONFIGEOF
################################################################################
##  whistor — Codespaces Test Environment Configuration                      ##
##  Generated: $(date '+%Y-%m-%d %H:%M:%S')                                        ##
################################################################################

  .onion address  : ${ONION_ADDRESS}
  Homeserver URL  : http://${ONION_ADDRESS}:8448

  NOTE: This is a Codespaces dev environment.
  The .onion address is reachable only over Tor from an external device.
  For local API testing, use http://localhost:8008 directly.

  Test account
  ────────────
  Username : ${TEST_USER}
  Password : ${TEST_PASS}
  Matrix ID: @${TEST_USER}:${ONION_ADDRESS}

  Proxy (for external Matrix clients)
  ────────────────────────────────────
  Type : SOCKS5
  Host : 127.0.0.1
  Port : 9050  (or 9150 if using Tor Browser)

  Admin commands
  ──────────────
  whistor user add USERNAME PASSWORD
  whistor user list
  whistor user delete USERNAME
  whistor logs
  whistor status

################################################################################
CONFIGEOF

chmod 600 "$CONFIG_FILE"
ok "whistor.config written"

# =============================================================================
# FINAL SUMMARY
# =============================================================================

echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔════════════════════════════════════════════════════════════╗"
echo "  ║         Codespace ready — whistor is running!             ║"
echo "  ╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}.onion address :${NC} ${CYAN}${ONION_ADDRESS}${NC}"
echo ""
echo -e "  ${BOLD}Test account   :${NC}"
echo -e "  ${DIM}  Username : ${TEST_USER}${NC}"
echo -e "  ${DIM}  Password : ${TEST_PASS}${NC}"
echo -e "  ${DIM}  Matrix ID: @${TEST_USER}:${ONION_ADDRESS}${NC}"
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "  ${DIM}  whistor status              — check container state${NC}"
echo -e "  ${DIM}  whistor logs                — follow live logs${NC}"
echo -e "  ${DIM}  whistor onion               — print .onion address${NC}"
echo -e "  ${DIM}  whistor user add NAME PASS  — create a new user${NC}"
echo -e "  ${DIM}  whistor user list           — list all users${NC}"
echo ""
echo -e "  ${BOLD}Test the Synapse API directly (no Tor needed inside Codespaces):${NC}"
echo -e "  ${DIM}  curl http://localhost:8008/_matrix/client/versions${NC}"
echo ""
echo -e "  ${BOLD}Connect from an external client (requires Tor):${NC}"
echo -e "  ${DIM}  Homeserver: http://${ONION_ADDRESS}:8448${NC}"
echo -e "  ${DIM}  Proxy: SOCKS5 / 127.0.0.1 / 9050${NC}"
echo ""
