#!/bin/bash
# KAAL OS — GRUB Theme Installer
# Installs the KAAL GRUB2 theme to /boot/grub2/themes/kaal/
# and sets it as the active GRUB theme.

set -euo pipefail

THEME_NAME="kaal"
THEME_SRC="$(dirname "$0")/../themes/${THEME_NAME}"
THEME_DST="/boot/grub2/themes/${THEME_NAME}"
GRUB_DEFAULT="/etc/default/grub"
GRUB_CONF_DIR="/etc/default/grub.d"

log() {
    echo "[kaal-grub-theme] $1"
}

# 1. Copy theme files
log "Installing GRUB theme to ${THEME_DST}..."
mkdir -p "$THEME_DST"

# Copy theme.txt and background
cp -f "$THEME_SRC/theme.txt" "$THEME_DST/"
cp -f "$THEME_SRC/background.svg" "$THEME_DST/"

# Convert SVG to PNG if background.png doesn't exist
if [[ ! -f "$THEME_SRC/background.png" ]]; then
    log "Converting background.svg to PNG (placeholder)..."
    if command -v rsvg-convert &>/dev/null; then
        rsvg-convert -w 1920 -h 1080 "$THEME_SRC/background.svg" -o "$THEME_DST/background.png"
    elif command -v convert &>/dev/null; then
        convert "$THEME_SRC/background.svg" -resize 1920x1080 "$THEME_DST/background.png"
    else
        log "WARNING: No SVG converter found. Place background.png manually at $THEME_DST/"
    fi
else
    cp -f "$THEME_SRC/background.png" "$THEME_DST/"
fi

# Copy any PNG assets if they exist
for f in "$THEME_SRC"/*.png; do
    [[ -f "$f" ]] && cp -f "$f" "$THEME_DST/"
done

# Copy fonts if any
mkdir -p "$THEME_DST/fonts"
for f in "$THEME_SRC"/fonts/*.pf2 "$THEME_SRC"/fonts/*.ttf; do
    [[ -f "$f" ]] && cp -f "$f" "$THEME_DST/fonts/"
done

# 2. Set GRUB_THEME in a drop-in config
log "Setting GRUB theme config..."
mkdir -p "$GRUB_CONF_DIR"
cat > "${GRUB_CONF_DIR}/05-kaal-theme.conf" << EOF
# KAAL OS GRUB Theme
GRUB_THEME="${THEME_DST}/theme.txt"
GRUB_BACKGROUND="${THEME_DST}/background.png"
GRUB_GFXMODE="1920x1080,auto"
GRUB_GFXPAYLOAD_LINUX="keep"
GRUB_TERMINAL_OUTPUT="gfxterm"
EOF

# 3. Regenerate GRUB config
log "Regenerating GRUB configuration..."
if [[ -x /usr/sbin/grub2-mkconfig ]]; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
elif [[ -x /usr/sbin/grub-mkconfig ]]; then
    grub-mkconfig -o /boot/grub/grub.cfg
else
    log "WARNING: grub2-mkconfig not found. Run manually after install."
fi

log "=== GRUB theme installed ==="
log "Theme: $THEME_NAME"
log "Background: $THEME_DST/background.png"
log "To replace: drop your background.png (1920x1080) at $THEME_DST/"
