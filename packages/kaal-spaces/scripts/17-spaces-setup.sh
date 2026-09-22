#!/bin/bash
# KAAL OS — Post-Install Script 17: Spaces Setup
# This script runs during ISO build and Calamares post-install to:
# 1. Install space configuration files
# 2. Enable the kaal-spaced daemon
# 3. Set the default space from Calamares selection
# 4. Create necessary state directories

set -euo pipefail

INSTALL_ROOT="${INSTALL_ROOT:-/}"

log() {
    echo "[kaal-spaces-setup] $1"
}

# ============================================================================
# 1. Create directories
# ============================================================================
log "Creating space directories..."

mkdir -p "${INSTALL_ROOT}/etc/kaal/spaces"
mkdir -p "${INSTALL_ROOT}/var/lib/kaal/spaces"
mkdir -p "${INSTALL_ROOT}/run/kaal"
mkdir -p "${INSTALL_ROOT}/usr/libexec/kaal-spaces/hooks"
mkdir -p "${INSTALL_ROOT}/usr/share/kaal/spaces"

# ============================================================================
# 2. Enable the daemon and targets
# ============================================================================
log "Enabling kaal-spaced service..."

if command -v systemctl &>/dev/null; then
    systemctl --root="${INSTALL_ROOT}" enable kaal-spaced.service 2>/dev/null || true

    # Enable the default space target
    DEFAULT_SPACE="${KAAL_DEFAULT_SPACE:-normal}"
    systemctl --root="${INSTALL_ROOT}" enable "kaal-space-${DEFAULT_SPACE}.target" 2>/dev/null || true

    log "Default space set to: ${DEFAULT_SPACE}"
fi

# ============================================================================
# 3. Set default space from Calamares global storage
# ============================================================================
# This is called by the post-install shellprocess with context env vars
if [[ -n "${KAAL_DEFAULT_SPACE:-}" ]]; then
    log "Setting default space from Calamares: ${KAAL_DEFAULT_SPACE}"

    mkdir -p "${INSTALL_ROOT}/var/lib/kaal/spaces"
    echo "${KAAL_DEFAULT_SPACE}" > "${INSTALL_ROOT}/var/lib/kaal/spaces/default-space"
    echo "${KAAL_DEFAULT_SPACE}" > "${INSTALL_ROOT}/var/lib/kaal/spaces/last-space"
else
    log "No Calamares space selection found, using default: normal"
    echo "normal" > "${INSTALL_ROOT}/var/lib/kaal/spaces/default-space"
    echo "normal" > "${INSTALL_ROOT}/var/lib/kaal/spaces/last-space"
fi

# ============================================================================
# 4. Install space icons (placeholder SVGs)
# ============================================================================
log "Creating space icons..."

for space in gaming development power normal; do
    icon_dir="${INSTALL_ROOT}/usr/share/kaal/spaces/${space}"
    mkdir -p "${icon_dir}"

    # Create placeholder icon SVG
    case "$space" in
        gaming)
            color="#FF6B35"; icon="🎮" ;;
        development)
            color="#4A90D9"; icon="💻" ;;
        power)
            color="#9B59B6"; icon="⚡" ;;
        normal)
            color="#2ECC71"; icon="🏠" ;;
    esac

    cat > "${icon_dir}/icon.svg" << SVGEOR
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="12" fill="${color}" opacity="0.2"/>
  <text x="32" y="44" font-size="32" text-anchor="middle" fill="${color}">${icon}</text>
</svg>
SVGEOR
done

# ============================================================================
# 5. Create space-env file for session initialization
# ============================================================================
log "Creating session environment file..."

mkdir -p "${INSTALL_ROOT}/etc/environment.d"
cat > "${INSTALL_ROOT}/etc/environment.d/50-kaal-space.conf" << 'EOF'
# KAAL OS Space environment (updated by kaal-spaced)
SPACE=normal
EOF

# ============================================================================
# 6. Install kaal-space binary as symlink if needed
# ============================================================================
if [[ ! -L "${INSTALL_ROOT}/usr/bin/kaal-space" ]]; then
    ln -sf /usr/libexec/kaal-spaces/kaal-space "${INSTALL_ROOT}/usr/bin/kaal-space" 2>/dev/null || true
fi

# ============================================================================
# 7. Add spaces to auto-update check
# ============================================================================
log "Adding spaces to auto-update configuration..."

# The auto-update timer should also check for space config updates
if [[ -f "${INSTALL_ROOT}/usr/libexec/kaal/kaal-update-check" ]]; then
    # Append space config check to update script
    if ! grep -q "kaal-spaces" "${INSTALL_ROOT}/usr/libexec/kaal/kaal-update-check" 2>/dev/null; then
        cat >> "${INSTALL_ROOT}/usr/libexec/kaal/kaal-update-check" << 'UPDATEEOF'

# Check for KAAL Spaces config updates
if [[ -d /etc/kaal/spaces ]]; then
    for conf in /etc/kaal/spaces/*.conf; do
        [[ -f "$conf" ]] || continue
        # Space configs are managed by the kaal-spaces package
        # NOTE: enable once the kaal-spaces RPM package exists:
        # dnf check-update kaal-spaces 2>/dev/null || true
    done
fi
UPDATEEOF
        log "Auto-update integration added"
    fi
fi

log "=== KAAL Spaces setup complete ==="
log "Default space: ${KAAL_DEFAULT_SPACE:-normal}"
log "Daemon: kaal-spaced.service (enabled at boot)"
log "CLI: kaal-space list | kaal-space switch <name>"
log "GUI: kaal-space-switcher"
