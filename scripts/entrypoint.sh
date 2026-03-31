#!/bin/bash
# =============================================================================
# entrypoint.sh — whistor Synapse container init script
# =============================================================================
#
# This script runs INSIDE the matrixdotorg/synapse container as the custom
# entrypoint defined in docker-compose.yml.
#
# It is executed every time the container starts, but most of its work only
# happens on FIRST BOOT (when /data/homeserver.yaml does not yet exist).
#
# First boot sequence:
#   1. Poll /tor-hs/hostname until the Tor daemon has written the .onion address
#   2. Generate random secrets (registration key, macaroon key, form secret)
#   3. Render homeserver.yaml from the template by replacing all placeholders
#   4. Generate the Synapse signing key (via --generate-keys)
#   5. Write a default logging configuration
#   6. Print a first-boot summary with the .onion address
#
# Subsequent boots:
#   - Detect that homeserver.yaml already exists → skip all init steps
#   - Start Synapse directly
#
# Volume layout (as seen from inside the container):
#   /data          — Synapse data (homeserver.yaml, DB, media, signing key)
#   /tor-hs        — read-only mount of the Tor hidden service volume
#                    (written by the Tor container, read here for the hostname)
#   /config        — read-only mount of config/ from the host repo
#                    (homeserver.template.yaml lives here)
#
# =============================================================================

# Abort on any error, treat unset variables as errors,
# and propagate failures through pipes.
set -euo pipefail

# =============================================================================
# PATHS
# =============================================================================

# Path to the rendered Synapse configuration file inside the container.
# This file does NOT exist on first boot — its absence triggers the init logic.
CONFIG_FILE="/data/homeserver.yaml"

# Path to the .onion hostname file written by the Tor container.
# This file is created by Tor once the hidden service key pair is generated.
ONION_HOSTNAME_FILE="/tor-hs/synapse/hostname"

# Path to the Synapse logging configuration file.
LOG_CONFIG_FILE="/data/log.config"

# =============================================================================
# LOGGING HELPERS
# =============================================================================

log() {
  # Prefix every message with a timestamp and the script name so it is easy
  # to identify whistor log lines in the combined docker compose output.
  echo "[whistor | $(date '+%H:%M:%S')] $*"
}

# =============================================================================
# FUNCTION: wait_for_onion
# =============================================================================
# Poll the Tor hostname file until it contains a valid .onion address.
# This is necessary because Tor needs several seconds to bootstrap and
# generate the hidden service key pair after it first starts.
#
# On success: sets the global variable ONION_ADDRESS and returns 0.
# On timeout: prints an error message and exits the script with code 1.
# =============================================================================
wait_for_onion() {
  log "Waiting for Tor hidden service hostname..."

  # Maximum number of polling attempts before giving up.
  local retries=60

  # Seconds to wait between attempts.
  local wait_sec=2

  for i in $(seq 1 "$retries"); do
    # Check that the file exists AND is non-empty (-s flag).
    # The file is created empty by some Tor versions before the address is written.
    if [[ -f "$ONION_HOSTNAME_FILE" && -s "$ONION_HOSTNAME_FILE" ]]; then
      # Strip all whitespace (newline, spaces) from the hostname.
      ONION_ADDRESS=$(cat "$ONION_HOSTNAME_FILE" | tr -d '[:space:]')
      log "Hidden service address: $ONION_ADDRESS"
      return 0
    fi

    log "Attempt $i/$retries — hostname not ready yet, retrying in ${wait_sec}s..."
    sleep "$wait_sec"
  done

  # If we reach here, Tor never produced the hostname file in time.
  log "ERROR: Tor hostname file never appeared at $ONION_HOSTNAME_FILE"
  log "Make sure the Tor container started correctly and that the"
  log "tor-data volume is shared between the tor and synapse services."
  exit 1
}

# =============================================================================
# FUNCTION: generate_config
# =============================================================================
# Performs the full first-boot initialisation:
#   - Waits for the .onion address
#   - Generates cryptographic secrets
#   - Renders homeserver.yaml from the template
#   - Generates the Synapse signing key
#   - Writes the logging configuration
# =============================================================================
generate_config() {
  log "First boot detected — running initialisation..."

  # ── Wait for the .onion address ──────────────────────────────────────────
  # ONION_ADDRESS is set as a global variable by wait_for_onion().
  wait_for_onion

  # ── Generate random secrets ───────────────────────────────────────────────
  # Each secret is a 32-byte (64 hex character) random value.
  # We use Python's secrets module (included in the Synapse image) rather
  # than openssl to avoid introducing an extra dependency.
  #
  # registration_shared_secret — used by the register_new_matrix_user tool
  #                              and by the admin API to create accounts.
  # macaroon_secret_key        — used to sign access tokens.
  # form_secret                — used for CSRF protection on login forms.
  log "Generating random secrets..."
  REGISTRATION_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  MACAROON_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  FORM_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")

  # ── Render homeserver.yaml from template ─────────────────────────────────
  # We use sed to replace the four placeholders defined in the template file.
  # Using sed with the | delimiter avoids conflicts with / characters that
  # may appear in paths or base64-encoded secrets.
  log "Rendering homeserver.yaml..."
  sed \
    -e "s|__ONION_ADDRESS__|${ONION_ADDRESS}|g" \
    -e "s|__REGISTRATION_SECRET__|${REGISTRATION_SECRET}|g" \
    -e "s|__MACAROON_SECRET__|${MACAROON_SECRET}|g" \
    -e "s|__FORM_SECRET__|${FORM_SECRET}|g" \
    /config/homeserver.template.yaml > "$CONFIG_FILE"

  log "homeserver.yaml written to $CONFIG_FILE"

  # ── Generate the Synapse signing key ─────────────────────────────────────
  # The signing key is used to sign federation events and server-to-server
  # requests. Even though federation is disabled in this deployment, Synapse
  # still requires the key file to exist at startup.
  # --generate-keys reads homeserver.yaml, determines the signing_key_path,
  # and writes a new ed25519 key pair if the file does not already exist.
  log "Generating Synapse signing key..."
  python3 -m synapse.app.homeserver \
    --config-path "$CONFIG_FILE" \
    --generate-keys

  # ── Write default logging configuration ──────────────────────────────────
  # Synapse requires a log config file at the path specified in homeserver.yaml.
  # We write a minimal config that sends INFO-level logs to stdout, which
  # makes them visible via `docker compose logs`.
  # SQL query logs are set to WARNING to reduce noise.
  if [[ ! -f "$LOG_CONFIG_FILE" ]]; then
    log "Writing default log configuration..."
    cat > "$LOG_CONFIG_FILE" << 'EOF'
version: 1

formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'

handlers:
  console:
    class: logging.StreamHandler
    formatter: precise

loggers:
  # Suppress verbose SQL query logging — set to WARNING to reduce noise.
  synapse.storage.SQL:
    level: WARNING

root:
  level: INFO
  handlers: [console]

disable_existing_loggers: false
EOF
  fi

  # ── First-boot summary ────────────────────────────────────────────────────
  log ""
  log "══════════════════════════════════════════════════════════════"
  log "  whistor — First Boot Complete"
  log ""
  log "  Your Matrix server is accessible at:"
  log "  matrix://${ONION_ADDRESS}"
  log ""
  log "  To create your first user on the HOST machine, run:"
  log "  whistor user add USERNAME PASSWORD"
  log ""
  log "  Or directly via Docker:"
  log "  docker exec -it synapse-server register_new_matrix_user \\"
  log "    -c /data/homeserver.yaml http://localhost:8008"
  log "══════════════════════════════════════════════════════════════"
  log ""
}

# =============================================================================
# MAIN — Decide whether to run first-boot init or skip straight to startup
# =============================================================================

if [[ ! -f "$CONFIG_FILE" ]]; then
  # homeserver.yaml does not exist — this is a first boot.
  generate_config
else
  # homeserver.yaml already exists — skip init and start Synapse directly.
  log "Existing configuration found at $CONFIG_FILE — skipping init."
fi

# =============================================================================
# START SYNAPSE
# =============================================================================
# Use exec to replace the current shell process with the Synapse process.
# This ensures that Docker signals (SIGTERM, SIGINT) are delivered directly
# to Synapse rather than to the bash wrapper, enabling clean graceful shutdown.
# =============================================================================
log "Starting Synapse homeserver..."
exec python3 -m synapse.app.homeserver \
  --config-path "$CONFIG_FILE"
