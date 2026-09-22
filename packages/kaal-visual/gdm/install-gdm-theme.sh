#!/bin/bash
# KAAL OS — GDM Theme Installer
# Installs the KAAL GDM login theme for GNOME.

set -euo pipefail

THEME_SRC="$(dirname "$0")/../themes/kaal"
THEME_DST="/usr/share/gdm/themes/kaal"

log() {
    echo "[kaal-gdm] $1"
}

# 1. Copy theme files
log "Installing GDM theme to ${THEME_DST}..."
mkdir -p "$THEME_DST"
cp -f "$THEME_SRC/gdm.css" "$THEME_DST/"

# Copy or convert background
if [[ -f "$THEME_SRC/background.png" ]]; then
    cp -f "$THEME_SRC/background.png" "$THEME_DST/"
else
    log "No background.png found. Place your 1920x1080 wallpaper at $THEME_DST/background.png"
fi

# 2. Apply CSS to GDM
log "Applying GDM CSS..."
# GNOME 45+ uses dconf for GDM styling
if command -v dconf &>/dev/null; then
    # Update GDM dconf profile
    GDM_CUSTOM="/etc/dconf/db/gdm.d/01-kaal-theme"
    mkdir -p "$(dirname "$GDM_CUSTOM")"
    cat > "$GDM_CUSTOM" << 'EOF'
[org/gnome/shell]
stylesheet-uri='file:///usr/share/gdm/themes/kaal/gdm.css'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/gdm/themes/kaal/background.png'
picture-uri-dark='file:///usr/share/gdm/themes/kaal/background.png'
picture-options='zoom'
EOF

    # Update GDM dconf profile to include our settings
    GDM_PROFILE="/etc/dconf/profile/gdm"
    if [[ ! -f "$GDM_PROFILE" ]]; then
        mkdir -p "$(dirname "$GDM_PROFILE")"
        cat > "$GDM_PROFILE" << 'EOF'
user-db:user
system-db:gdm
EOF
    fi

    dconf update
    log "GDM dconf profile updated"
else
    log "WARNING: dconf not found. Manual GDM configuration required."
fi

log "=== GDM theme installed ==="
log "CSS: $THEME_DST/gdm.css"
log "Background: $THEME_DST/background.png"
log "To customize: edit $THEME_DST/gdm.css or replace background.png"
