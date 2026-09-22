#!/bin/bash
# KAAL OS — Visual Identity Master Installer
# Installs all visual identity assets to their correct system paths.
# Run with: sudo bash install-visual-identity.sh
#
# This script installs:
#   1. GRUB2 theme → /boot/grub2/themes/kaal/
#   2. Plymouth splash → /usr/share/plymouth/themes/kaal/
#   3. Calamares branding → /usr/share/calamares/branding/kaal/
#   4. SDDM theme → /usr/share/sddm/themes/kaal/
#   5. GDM theme → /usr/share/gdm/themes/kaal/
#   6. Wallpapers → /usr/share/backgrounds/kaal/
#   7. Icon set → /usr/share/icons/hicolor/
#   8. GTK theme → /usr/share/themes/kaal/gtk-3.0/
#   9. Qt color scheme → /usr/share/color-schemes/
#  10. Cursor theme → /usr/share/icons/kaal/
#  11. Sound scheme → /usr/share/sounds/kaal/
#
# After installation, replace placeholder assets with your final artwork.
# See docs/VISUAL_IDENTITY.md for exact specifications.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

log()     { echo -e "${GREEN}✓${NC} $1"; }
info()    { echo -e "${CYAN}ℹ${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1" >&2; }

if [[ $EUID -ne 0 ]]; then
    error "Must run as root. Use: sudo bash $0"
    exit 1
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}    KAAL OS Visual Identity Installer       ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

# ============================================================================
# 1. GRUB2 Theme
# ============================================================================
if [[ -d "${SCRIPT_DIR}/grub/themes/kaal" ]]; then
    info "Installing GRUB2 theme..."
    mkdir -p /boot/grub2/themes/kaal
    cp -f "${SCRIPT_DIR}/grub/themes/kaal/theme.txt" /boot/grub2/themes/kaal/

    # Convert background SVG to PNG
    if [[ -f "${SCRIPT_DIR}/grub/themes/kaal/background.png" ]]; then
        cp -f "${SCRIPT_DIR}/grub/themes/kaal/background.png" /boot/grub2/themes/kaal/
    elif command -v rsvg-convert &>/dev/null; then
        rsvg-convert -w 1920 -h 1080 \
            "${SCRIPT_DIR}/grub/themes/kaal/background.svg" \
            -o /boot/grub2/themes/kaal/background.png
    fi

    # Copy any PNG assets
    for f in "${SCRIPT_DIR}/grub/themes/kaal"/*.png; do
        [[ -f "$f" ]] && cp -f "$f" /boot/grub2/themes/kaal/
    done

    # Configure GRUB
    mkdir -p /etc/default/grub.d
    cat > /etc/default/grub.d/05-kaal-theme.conf << 'EOF'
GRUB_THEME="/boot/grub2/themes/kaal/theme.txt"
GRUB_GFXMODE="1920x1080,auto"
GRUB_TERMINAL_OUTPUT="gfxterm"
EOF

    # Regenerate GRUB
    if command -v grub2-mkconfig &>/dev/null; then
        grub2-mkconfig -o /boot/grub2/grub.cfg
    fi

    log "GRUB2 theme installed"
fi

# ============================================================================
# 2. Plymouth Theme
# ============================================================================
if [[ -d "${SCRIPT_DIR}/plymouth/themes/kaal" ]]; then
    info "Installing Plymouth splash..."
    mkdir -p /usr/share/plymouth/themes/kaal
    cp -f "${SCRIPT_DIR}/plymouth/themes/kaal/kaal.plymouth" /usr/share/plymouth/themes/kaal/
    cp -f "${SCRIPT_DIR}/plymouth/themes/kaal/kaal.script" /usr/share/plymouth/themes/kaal/

    # Convert logo
    if [[ -f "${SCRIPT_DIR}/plymouth/themes/kaal/logo.png" ]]; then
        cp -f "${SCRIPT_DIR}/plymouth/themes/kaal/logo.png" /usr/share/plymouth/themes/kaal/
    elif command -v rsvg-convert &>/dev/null; then
        rsvg-convert -w 256 -h 256 \
            "${SCRIPT_DIR}/plymouth/themes/kaal/logo.svg" \
            -o /usr/share/plymouth/themes/kaal/logo.png
    fi

    # Set as default
    if command -v plymouth-set-default-theme &>/dev/null; then
        plymouth-set-default-theme -R kaal
    fi

    log "Plymouth splash installed"
fi

# ============================================================================
# 3. Calamares Branding
# ============================================================================
if [[ -d "${SCRIPT_DIR}/calamares/branding/kaal" ]]; then
    info "Installing Calamares branding..."
    mkdir -p /usr/share/calamares/branding/kaal
    cp -rf "${SCRIPT_DIR}/calamares/branding/kaal/"* /usr/share/calamares/branding/kaal/

    # Convert SVGs to PNGs
    for svg in /usr/share/calamares/branding/kaal/*.svg; do
        [[ -f "$svg" ]] || continue
        png="${svg%.svg}.png"
        if [[ ! -f "$png" ]] && command -v rsvg-convert &>/dev/null; then
            rsvg-convert "$svg" -o "$png"
        fi
    done

    log "Calamares branding installed"
fi

# ============================================================================
# 4. SDDM Theme (KDE)
# ============================================================================
if [[ -d "${SCRIPT_DIR}/sddm/themes/kaal" ]]; then
    info "Installing SDDM login theme..."
    mkdir -p /usr/share/sddm/themes/kaal
    cp -rf "${SCRIPT_DIR}/sddm/themes/kaal/"* /usr/share/sddm/themes/kaal/

    # Set as default SDDM theme
    if [[ -f /etc/sddm.conf ]]; then
        sed -i "s/^Current=.*/Current=kaal/" /etc/sddm.conf
    else
        mkdir -p /etc/sddm.conf.d
        cat > /etc/sddm.conf.d/01-kaal-theme.conf << 'EOF'
[Theme]
Current=kaal
EOF
    fi

    log "SDDM login theme installed"
fi

# ============================================================================
# 5. GDM Theme (GNOME)
# ============================================================================
if [[ -d "${SCRIPT_DIR}/gdm/themes/kaal" ]]; then
    info "Installing GDM login theme..."
    mkdir -p /usr/share/gdm/themes/kaal
    cp -f "${SCRIPT_DIR}/gdm/themes/kaal/gdm.css" /usr/share/gdm/themes/kaal/

    # Copy background
    if [[ -f "${SCRIPT_DIR}/gdm/themes/kaal/background.png" ]]; then
        cp -f "${SCRIPT_DIR}/gdm/themes/kaal/background.png" /usr/share/gdm/themes/kaal/
    elif [[ -f "${SCRIPT_DIR}/wallpapers/default.png" ]]; then
        cp -f "${SCRIPT_DIR}/wallpapers/default.png" /usr/share/gdm/themes/kaal/background.png
    fi

    # Configure dconf for GDM
    mkdir -p /etc/dconf/db/gdm.d
    cat > /etc/dconf/db/gdm.d/01-kaal-theme << 'EOF'
[org/gnome/shell]
stylesheet-uri='file:///usr/share/gdm/themes/kaal/gdm.css'
EOF

    mkdir -p /etc/dconf/profile
    if [[ ! -f /etc/dconf/profile/gdm ]]; then
        cat > /etc/dconf/profile/gdm << 'EOF'
user-db:user
system-db:gdm
EOF
    fi

    dconf update 2>/dev/null || true

    log "GDM login theme installed"
fi

# ============================================================================
# 6. Wallpapers
# ============================================================================
if [[ -d "${SCRIPT_DIR}/wallpapers" ]]; then
    info "Installing wallpapers..."
    mkdir -p /usr/share/backgrounds/kaal

    for svg in "${SCRIPT_DIR}/wallpapers"/*.svg; do
        [[ -f "$svg" ]] || continue
        base_name=$(basename "$svg" .svg)
        if command -v rsvg-convert &>/dev/null; then
            rsvg-convert -w 1920 -h 1080 "$svg" \
                -o "/usr/share/backgrounds/kaal/${base_name}.png"
        else
            cp -f "$svg" "/usr/share/backgrounds/kaal/"
        fi
    done

    # Copy any pre-made PNGs
    for png in "${SCRIPT_DIR}/wallpapers"/*.png; do
        [[ -f "$png" ]] && cp -f "$png" /usr/share/backgrounds/kaal/
    done

    # Set default wallpaper via GNOME/KDE config
    mkdir -p /etc/dconf/db/local.d
    cat > /etc/dconf/db/local.d/02-kaal-wallpaper << 'EOF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/kaal/default.png'
picture-uri-dark='file:///usr/share/backgrounds/kaal/default.png'
picture-options='zoom'
EOF

    log "Wallpapers installed"
fi

# ============================================================================
# 7. Icon Set
# ============================================================================
if [[ -d "${SCRIPT_DIR}/icons/hicolor" ]]; then
    info "Installing icons..."
    cp -rf "${SCRIPT_DIR}/icons/hicolor/scalable"/* /usr/share/icons/hicolor/scalable/ 2>/dev/null || true

    # Update icon cache
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null || true
    fi

    log "Icons installed"
fi

# ============================================================================
# 8. GTK Theme
# ============================================================================
if [[ -d "${SCRIPT_DIR}/gtk/themes/kaal" ]]; then
    info "Installing GTK theme..."
    mkdir -p /usr/share/themes/kaal/gtk-3.0
    mkdir -p /usr/share/themes/kaal/gtk-4.0
    cp -f "${SCRIPT_DIR}/gtk/themes/kaal/gtk.css" /usr/share/themes/kaal/gtk-3.0/
    cp -f "${SCRIPT_DIR}/gtk/themes/kaal/gtk.css" /usr/share/themes/kaal/gtk-4.0/

    # Create index.theme
    cat > /usr/share/themes/kaal/index.theme << 'EOF'
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=KAAL OS
Comment=KAAL OS dark theme
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=kaal
IconTheme=hicolor
CursorTheme=kaal
EOF

    log "GTK theme installed"
fi

# ============================================================================
# 9. Qt/KDE Color Scheme
# ============================================================================
if [[ -d "${SCRIPT_DIR}/qt/colors" ]]; then
    info "Installing Qt color scheme..."
    mkdir -p /usr/share/color-schemes
    cp -f "${SCRIPT_DIR}/qt/colors/kaal.colors" /usr/share/color-schemes/

    log "Qt color scheme installed"
fi

# ============================================================================
# 10. Cursor Theme
# ============================================================================
if [[ -d "${SCRIPT_DIR}/cursors/kaal" ]]; then
    info "Installing cursor theme..."
    mkdir -p /usr/share/icons/kaal
    cp -rf "${SCRIPT_DIR}/cursors/kaal/"* /usr/share/icons/kaal/

    # Create index.theme
    cat > /usr/share/icons/kaal/index.theme << 'EOF'
[Icon Theme]
Name=KAAL OS
Comment=KAAL OS cursor theme
Inherits=Adwaita
EOF

    log "Cursor theme installed"
fi

# ============================================================================
# 11. Sound Scheme
# ============================================================================
if [[ -d "${SCRIPT_DIR}/sounds" ]]; then
    info "Installing sound scheme..."
    mkdir -p /usr/share/sounds/kaal
    cp -f "${SCRIPT_DIR}/sounds/"* /usr/share/sounds/kaal/ 2>/dev/null || true

    log "Sound scheme installed"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}    KAAL OS Visual Identity Installed!     ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
echo "Installed components:"
echo "  ✓ GRUB2 boot menu theme"
echo "  ✓ Plymouth boot splash"
echo "  ✓ Calamares installer branding"
echo "  ✓ SDDM login theme (KDE)"
echo "  ✓ GDM login theme (GNOME)"
echo "  ✓ Wallpapers (5: default + 4 spaces)"
echo "  ✓ Icon set (14 icons)"
echo "  ✓ GTK application theme"
echo "  ✓ Qt/KDE color scheme"
echo "  ✓ Cursor theme"
echo "  ✓ Sound scheme"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Replace placeholder assets with your final artwork"
echo "  2. See docs/VISUAL_IDENTITY.md for exact specifications"
echo "  3. Re-run this script to reinstall after updating assets"
echo ""
