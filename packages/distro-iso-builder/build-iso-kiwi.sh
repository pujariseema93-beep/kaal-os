#!/bin/bash
# =============================================================================
# build-iso-kiwi.sh — KAAL OS ISO Build via kiwi-NG (Alternative)
# =============================================================================
# Alternative build script using kiwi-NG instead of livemedia-creator.
# kiwi-NG produces a cleaner image and supports more output formats.
#
# Requirements:
#   - Fedora 40+ host (or container)
#   - Root privileges
#   - kiwi-cli, kiwi-system-dependencies packages
#   - ~20GB free disk space
#
# Usage:
#   sudo ./build-iso-kiwi.sh [--target /var/tmp/kiwi-build] [--name DISTRO_NAME]
#
# Install kiwi-NG first:
#   sudo dnf install kiwi-cli kiwi-system-dependencies
# =============================================================================

set -euo pipefail

TARGET="/var/tmp/kiwi-build"
DISTRO_NAME="KAAL OS"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
    case $1 in
        --target)  TARGET="$2"; shift 2 ;;
        --name)    DISTRO_NAME="$2"; shift 2 ;;
        --help|-h) head -25 "$0" | tail -23; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo ""
echo "============================================"
echo "  $DISTRO_NAME — ISO Build (kiwi-NG)"
echo "============================================"
echo ""

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Must be run as root (use sudo)"
    exit 1
fi

# Check kiwi
if ! command -v kiwi-ng >/dev/null 2>&1; then
    echo "ERROR: kiwi-ng not found"
    echo "Install: sudo dnf install kiwi-cli kiwi-system-dependencies"
    exit 1
fi

# Prepare description
DESC_DIR="$TARGET/description"
mkdir -p "$DESC_DIR"
cp "$SCRIPT_DIR/kiwi/distro-live.xml" "$DESC_DIR/"
sed -i "s/\[DISTRO_NAME\]/$DISTRO_NAME/g" "$DESC_DIR/distro-live.xml"

# Build
echo "Building ISO with kiwi-NG..."
kiwi-ng system build \
    --description "$DESC_DIR" \
    --target-dir "$TARGET" \
    2>&1 | tee "$TARGET/build.log"

# Find result
ISO_FILE=$(find "$TARGET" -name "*.iso" -type f | head -1)

if [ -z "$ISO_FILE" ]; then
    echo "ERROR: No ISO produced. Check $TARGET/build.log"
    exit 1
fi

# Generate checksums
cd "$(dirname "$ISO_FILE")"
sha256sum "$(basename "$ISO_FILE")" > "$(basename "$ISO_FILE").sha256"

echo ""
echo "============================================"
echo "  ISO created: $ISO_FILE"
echo "  Size: $(du -h "$ISO_FILE" | cut -f1)"
echo "============================================"
echo ""
echo "To create a bootable USB:"
echo "  sudo dd if=$ISO_FILE of=/dev/sdX bs=4M status=progress"
