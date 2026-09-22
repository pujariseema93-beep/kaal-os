#!/bin/bash
# =============================================================================
# assemble-all.sh — Assemble All Packages Into Install Tree
# =============================================================================
# Collects files from all 5 packages (bootloader, iso-builder, calamares,
# hardware, ci) into a single directory tree that can be copied into
# a kickstart build or packaged as RPMs.
#
# Usage: ./ci/assemble-all.sh [output_dir]
# Default output: build-tree/
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR/build-tree}"

GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}[assemble]${NC} $*"; }

log "Assembling all packages into: $OUTPUT_DIR"

# ---- Clean output dir ----
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# ---- Create directory structure ----
mkdir -p "$OUTPUT_DIR"/{etc/default/grub.d,etc/grub.d,etc/dracut.conf.d,etc/calamares/modules,etc/distro-bootloader}
mkdir -p "$OUTPUT_DIR"/usr/{libexec/distro-installer,libexec/distro-bootloader,libexec/distro-hardware}
mkdir -p "$OUTPUT_DIR"/usr/lib/calamares/{modules,branding}
mkdir -p "$OUTPUT_DIR"/usr/share/{distro/profiles,distro-bootloader/{systemd-boot,kernel-params},doc/distro-bootloader}

# ---- 1. Bootloader package ----
log "Copying bootloader package..."
if [ -d "$SCRIPT_DIR/distro-bootloader" ]; then
    cp -r "$SCRIPT_DIR/distro-bootloader/etc/"* "$OUTPUT_DIR/etc/" 2>/dev/null || true
    cp -r "$SCRIPT_DIR/distro-bootloader/usr/"* "$OUTPUT_DIR/usr/" 2>/dev/null || true
    log "  Bootloader files copied"
fi

# ---- 2. ISO builder scripts ----
log "Copying installer scripts..."
if [ -d "$SCRIPT_DIR/distro-iso-builder/scripts" ]; then
    cp "$SCRIPT_DIR/distro-iso-builder/scripts/"*.sh "$OUTPUT_DIR/usr/libexec/distro-installer/"
    log "  Installer scripts copied ($(ls "$OUTPUT_DIR/usr/libexec/distro-installer/"*.sh 2>/dev/null | wc -l) files)"
fi

# ---- 3. Hardware scripts ----
log "Copying hardware scripts..."
if [ -d "$SCRIPT_DIR/distro-hardware/scripts" ]; then
    cp "$SCRIPT_DIR/distro-hardware/scripts/"*.sh "$OUTPUT_DIR/usr/libexec/distro-installer/"
    log "  Hardware scripts copied ($(ls "$SCRIPT_DIR/distro-hardware/scripts/"*.sh 2>/dev/null | wc -l) files)"
fi

# ---- 4. Software profiles ----
log "Copying software profiles..."
if [ -d "$SCRIPT_DIR/distro-iso-builder/profiles" ]; then
    cp "$SCRIPT_DIR/distro-iso-builder/profiles/"*.list "$OUTPUT_DIR/usr/share/distro/profiles/"
    log "  Profiles copied ($(ls "$OUTPUT_DIR/usr/share/distro/profiles/"*.list 2>/dev/null | wc -l) files)"
fi

# ---- 5. Calamares modules ----
log "Copying Calamares modules..."
if [ -d "$SCRIPT_DIR/distro-calamares/modules" ]; then
    for mod_dir in "$SCRIPT_DIR/distro-calamares/modules/"*/; do
        mod_name=$(basename "$mod_dir")
        if [ -f "$mod_dir/module.desc" ] || [ -f "$mod_dir/main.py" ]; then
            mkdir -p "$OUTPUT_DIR/usr/lib/calamares/modules/$mod_name"
            cp "$mod_dir"/* "$OUTPUT_DIR/usr/lib/calamares/modules/$mod_name/" 2>/dev/null || true
            log "  Module: $mod_name"
        fi
    done
fi

# ---- 6. Calamares settings ----
log "Copying Calamares settings..."
if [ -f "$SCRIPT_DIR/distro-calamares/settings.conf" ]; then
    cp "$SCRIPT_DIR/distro-calamares/settings.conf" "$OUTPUT_DIR/etc/calamares/settings.conf"
fi
if [ -f "$SCRIPT_DIR/distro-hardware/config/distro-post-install-v2.conf" ]; then
    cp "$SCRIPT_DIR/distro-hardware/config/distro-post-install-v2.conf" \
       "$OUTPUT_DIR/etc/calamares/modules/distro-post-install.conf"
elif [ -f "$SCRIPT_DIR/distro-calamares/modules/distro-post-install.conf" ]; then
    cp "$SCRIPT_DIR/distro-calamares/modules/distro-post-install.conf" \
       "$OUTPUT_DIR/etc/calamares/modules/distro-post-install.conf"
fi

# ---- 7. Calamares branding ----
log "Copying Calamares branding..."
if [ -d "$SCRIPT_DIR/distro-calamares/branding" ]; then
    cp -r "$SCRIPT_DIR/distro-calamares/branding/"* "$OUTPUT_DIR/usr/lib/calamares/branding/"
fi

# ---- 8. Kickstart file ----
log "Copying kickstart..."
if [ -f "$SCRIPT_DIR/distro-iso-builder/distro-live.ks" ]; then
    cp "$SCRIPT_DIR/distro-iso-builder/distro-live.ks" "$OUTPUT_DIR/distro-live.ks"
fi

# ---- 9. Build scripts ----
log "Copying build scripts..."
if [ -f "$SCRIPT_DIR/distro-iso-builder/build-iso.sh" ]; then
    cp "$SCRIPT_DIR/distro-iso-builder/build-iso.sh" "$OUTPUT_DIR/build-iso.sh"
fi
if [ -f "$SCRIPT_DIR/distro-iso-builder/build-iso-kiwi.sh" ]; then
    cp "$SCRIPT_DIR/distro-iso-builder/build-iso-kiwi.sh" "$OUTPUT_DIR/build-iso-kiwi.sh"
fi

# ---- 10. QEMU test script ----
if [ -f "$SCRIPT_DIR/ci/qemu-boot-test.sh" ]; then
    cp "$SCRIPT_DIR/ci/qemu-boot-test.sh" "$OUTPUT_DIR/usr/libexec/distro-bootloader/qemu-boot-test.sh"
fi

# ---- Make all scripts executable ----
log "Making scripts executable..."
find "$OUTPUT_DIR" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
chmod +x "$OUTPUT_DIR/etc/grub.d/0"-distro* 2>/dev/null || true
chmod +x "$OUTPUT_DIR/etc/grub.d/2"-distro* 2>/dev/null || true
chmod +x "$OUTPUT_DIR/usr/libexec/distro-bootloader/"* 2>/dev/null || true
chmod +x "$OUTPUT_DIR/usr/libexec/distro-installer/"* 2>/dev/null || true

# ---- Summary ----
log ""
log "=== Assembly Complete ==="
log "Output: $OUTPUT_DIR"
TOTAL_FILES=$(find "$OUTPUT_DIR" -type f | wc -l)
TOTAL_DIRS=$(find "$OUTPUT_DIR" -type d | wc -l)
log "Files: $TOTAL_FILES"
log "Directories: $TOTAL_DIRS"
log ""
log "Tree structure:"
find "$OUTPUT_DIR" -maxdepth 3 -type d | sort | sed "s|$OUTPUT_DIR|.|"
log ""
log "To use in kickstart:"
log "  cp -r $OUTPUT_DIR/* /path/to/chroot/"
