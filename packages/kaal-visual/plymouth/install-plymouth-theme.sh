#!/bin/bash
# KAAL OS — Plymouth Theme Installer
# Installs the KAAL Plymouth boot splash theme.

set -euo pipefail

THEME_NAME="kaal"
THEME_SRC="$(dirname "$0")/../themes/${THEME_NAME}"
THEME_DST="/usr/share/plymouth/themes/${THEME_NAME}"

log() {
    echo "[kaal-plymouth] $1"
}

# 1. Copy theme files
log "Installing Plymouth theme to ${THEME_DST}..."
mkdir -p "$THEME_DST"

cp -f "$THEME_SRC/kaal.plymouth" "$THEME_DST/"
cp -f "$THEME_SRC/kaal.script" "$THEME_DST/"

# Convert logo SVG to PNG
if [[ ! -f "$THEME_SRC/logo.png" ]]; then
    if command -v rsvg-convert &>/dev/null; then
        rsvg-convert -w 256 -h 256 "$THEME_SRC/logo.svg" -o "$THEME_DST/logo.png"
        log "Converted logo.svg to logo.png (placeholder)"
    else
        log "WARNING: No SVG converter. Place logo.png manually (256x256 with alpha)."
        cp -f "$THEME_SRC/logo.svg" "$THEME_DST/logo.svg"
    fi
else
    cp -f "$THEME_SRC/logo.png" "$THEME_DST/"
fi

# Copy spinner frames if they exist
for f in "$THEME_SRC"/frame-*.png; do
    [[ -f "$f" ]] && cp -f "$f" "$THEME_DST/"
done

# If no spinner frames exist, generate simple ones
if ! ls "$THEME_DST"/frame-*.png &>/dev/null; then
    log "No spinner frames found, creating simple placeholder frames..."
    for i in $(seq 1 8); do
        angle=$((i * 45))
        cat > "$THEME_DST/frame-$(printf '%02d' $i).svg" << EOFRAME
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
  <circle cx="12" cy="12" r="10" fill="none" stroke="#333" stroke-width="2"/>
  <circle cx="12" cy="2" r="3" fill="#4A90D9" transform="rotate($angle 12 12)"/>
</svg>
EOFRAME
        if command -v rsvg-convert &>/dev/null; then
            rsvg-convert -w 24 -h 24 "$THEME_DST/frame-$(printf '%02d' $i).svg" \
                -o "$THEME_DST/frame-$(printf '%02d' $i).png"
            rm -f "$THEME_DST/frame-$(printf '%02d' $i).svg"
        fi
    done
    log "Created 8 spinner frames (placeholders)"
fi

# 2. Set as default Plymouth theme
log "Setting KAAL as default Plymouth theme..."
if command -v plymouth-set-default-theme &>/dev/null; then
    plymouth-set-default-theme -R "$THEME_NAME"
    log "Plymouth theme set and initrd regenerated"
else
    # Manual config
    sed -i "s/^Theme=.*/Theme=$THEME_NAME/" /etc/plymouth/plymouthd.conf 2>/dev/null || true
    log "Set theme in plymouthd.conf. Run: dracut -f to regenerate initrd."
fi

log "=== Plymouth theme installed ==="
log "Theme: $THEME_NAME"
log "Logo: $THEME_DST/logo.png (replace with 256x256 PNG with alpha)"
log "Spinner: $THEME_DST/frame-01.png through frame-08.png (replace with 24x24 PNGs)"
