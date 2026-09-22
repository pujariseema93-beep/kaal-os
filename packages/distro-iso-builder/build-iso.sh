#!/bin/bash
# =============================================================================
# build-iso.sh — KAAL OS ISO Build Script
# =============================================================================
# Builds a bootable live ISO image using livemedia-creator (lorax).
#
# Requirements:
#   - Fedora 40+ host system (or a Fedora container)
#   - Root privileges (sudo)
#   - ~20GB free disk space
#   - livemedia-creator, lorax, lorax-composer packages
#
# Usage:
#   sudo ./build-iso.sh [--releasever 42] [--workdir /var/tmp/build] \
#     [--resultdir ./results] [--profile all] [--name DISTRO_NAME]
#
# Options:
#   --releasever   Fedora release version (default: 42)
#   --workdir      Working directory for build (default: /var/tmp/distro-build)
#   --resultdir    Where to put the final ISO (default: ./results)
#   --profile      Which profile to build: all, gaming, developer, power-user, daily, minimal
#                  (default: all — includes all profiles, user selects at install time)
#   --name         Distro name (default: KAAL OS)
#   --compress     ISO compression: xz (default, slow/small), gzip (fast/large)
#   --volid        ISO volume label (default: DISTRO_LIVE)
#   --keep-workdir Don't clean up workdir after build
#   --help         Show this help
#
# =============================================================================

set -euo pipefail

# ---- Default configuration ----
RELEASEVER="42"
WORKDIR="/var/tmp/distro-build"
RESULTDIR="./results"
PROFILE="all"
DISTRO_NAME="KAAL OS"
COMPRESS="xz"
VOLID="DISTRO_LIVE"
KEEP_WORKDIR=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Parse arguments ----
while [[ $# -gt 0 ]]; do
    case $1 in
        --releasever)  RELEASEVER="$2"; shift 2 ;;
        --workdir)     WORKDIR="$2"; shift 2 ;;
        --resultdir)   RESULTDIR="$2"; shift 2 ;;
        --profile)     PROFILE="$2"; shift 2 ;;
        --name)        DISTRO_NAME="$2"; shift 2 ;;
        --compress)    COMPRESS="$2"; shift 2 ;;
        --volid)       VOLID="$2"; shift 2 ;;
        --keep-workdir) KEEP_WORKDIR=true; shift ;;
        --help|-h)
            head -30 "$0" | tail -28
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ---- Colors ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[$DISTRO_NAME build]${NC} $*"; }
warn()   { echo -e "${YELLOW}[$DISTRO_NAME build]${NC} WARNING: $*"; }
error()  { echo -e "${RED}[$DISTRO_NAME build]${NC} ERROR: $*" >&2; }
info()   { echo -e "${BLUE}[$DISTRO_NAME build]${NC} $*"; }

# ---- Pre-flight checks ----
preflight() {
    log "Running pre-flight checks..."

    # Check root
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root (use sudo)."
        exit 1
    fi

    # Check for required tools
    local missing=()
    for cmd in livemedia-creator lorax xorriso; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}"
        error "Install them with: dnf install lorax lorax-composer xorriso"
        exit 1
    fi

    # Check disk space (need ~20GB)
    local available_kb
    available_kb=$(df --output=avail -k "$(dirname "$WORKDIR")" | tail -1)
    if [ "$available_kb" -lt 20971520 ]; then
        warn "Less than 20GB free in $(dirname "$WORKDIR") — build may fail"
    fi

    # Check kickstart file
    if [ ! -f "$SCRIPT_DIR/distro-live.ks" ]; then
        error "Kickstart file not found: $SCRIPT_DIR/distro-live.ks"
        exit 1
    fi

    log "Pre-flight checks passed."
}

# ---- Install build dependencies ----
install_deps() {
    log "Ensuring build dependencies are installed..."
    dnf install -y lorax lorax-composer xorriso isomd5sum \
        pykickstart livecd-tools 2>/dev/null || true
}

# ---- Prepare kickstart ----
prepare_kickstart() {
    log "Preparing kickstart file..."

    local ks_file="$WORKDIR/distro-live.ks"

    # Copy kickstart
    cp "$SCRIPT_DIR/distro-live.ks" "$ks_file"

    # Replace placeholders
    sed -i "s/\[DISTRO_NAME\]/$DISTRO_NAME/g" "$ks_file"
    sed -i "s/\[distro\]/$(echo "$DISTRO_NAME" | tr '[:upper:]' '[:lower:]')/g" "$ks_file"
    sed -i "s/BUILD_DATE_PLACEHOLDER/$(date '+%Y-%m-%d %H:%M:%S')/g" "$ks_file"

    # Validate kickstart syntax
    log "Validating kickstart..."
    if ksvalidator "$ks_file" 2>/dev/null; then
        log "Kickstart is valid."
    else
        warn "Kickstart validation failed — continuing anyway (ksvalidator may be strict)"
    fi
}

# ---- Build the ISO ----
build_iso() {
    log "Starting ISO build..."
    log "  Release:  Fedora $RELEASEVER"
    log "  Profile:  $PROFILE"
    log "  Workdir:  $WORKDIR"
    log "  Results:  $RESULTDIR"
    log "  Compress: $COMPRESS"

    mkdir -p "$WORKDIR" "$RESULTDIR"

    local ks_file="$WORKDIR/distro-live.ks"


# ---- KAAL OS v2: stage all packages for kickstart %post --nochroot ----
STAGE_DIR="/tmp/kaal-staging"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
echo "[build] Staging packages into $STAGE_DIR ..."
for pkg in distro-bootloader distro-iso-builder distro-calamares distro-hardware kaal-spaces kaal-visual kaal-security; do
    if [ -d "$SCRIPT_DIR/../$pkg" ]; then
        cp -r "$SCRIPT_DIR/../$pkg" "$STAGE_DIR/"
        echo "[build]   staged: $pkg"
    else
        echo "[build]   WARNING: package $pkg not found (skipping)"
    fi
done

    # Run livemedia-creator
    # --no-virt: don't use a VM (build directly in chroot)
    # --image-only: just build the image, don't test it
    # --tmp: working directory
    # --resultdir: where to put results
    livemedia-creator \
        --ks "$ks_file" \
        --no-virt \
        --image-only \
        --tmp "$WORKDIR" \
        --resultdir "$RESULTDIR" \
        --iso-label "$VOLID" \
        --releasever "$RELEASEVER" \
        --title "$DISTRO_NAME Live" \
        --project "$DISTRO_NAME" \
        --volid "$VOLID" \
        --make-iso \
        --compress "$COMPRESS" \
        2>&1 | tee "$RESULTDIR/build.log"

    local status=$?

    if [ $status -ne 0 ]; then
        error "ISO build failed! Check $RESULTDIR/build.log for details."
        exit $status
    fi

    log "ISO build completed."
}

# ---- Post-build ----
post_build() {
    log "Post-build processing..."

    # Find the generated ISO
    local iso_file
    iso_file=$(find "$RESULTDIR" -name "*.iso" -type f | head -1)
    true

    if [ -z "$iso_file" ]; then
        error "No ISO file found in $RESULTDIR"
        exit 1
    fi

    # Rename to our distro name
    local new_name="$RESULTDIR/${DISTRO_NAME}_$(date '+%Y%m%d')_live_x86_64.iso"
    mv "$iso_file" "$new_name"

    # Generate checksums
    log "Generating checksums..."
    cd "$RESULTDIR"
    sha256sum "$(basename "$new_name")" > "$(basename "$new_name").sha256"
    md5sum "$(basename "$new_name")" > "$(basename "$new_name").md5"
    cd - >/dev/null

    # Check ISO size
    local iso_size
    iso_size=$(du -h "$new_name" | cut -f1)
    log "ISO size: $iso_size"

    # Verify ISO is bootable
    log "Verifying ISO..."
    if checkisomd5 --verbose "$new_name" 2>/dev/null; then
        log "ISO verification passed."
    else
        warn "ISO verification failed — ISO may not be bootable"
    fi

    log "ISO created: $new_name"
    echo ""
    echo "============================================"
    echo "  $DISTRO_NAME Live ISO"
    echo "  File: $new_name"
    echo "  Size: $iso_size"
    echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================"
    echo ""
    echo "To create a bootable USB:"
    echo "  sudo dd if=$new_name of=/dev/sdX bs=4M status=progress"
    echo "  # or"
    echo "  sudo FedoraMediaWriter $new_name"
    echo ""
}

# ---- Cleanup ----
cleanup() {
    if [ "$KEEP_WORKDIR" = false ]; then
        log "Cleaning up workdir ($WORKDIR)..."
        rm -rf "$WORKDIR"
    else
        log "Keeping workdir (--keep-workdir): $WORKDIR"
    fi
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo ""
    echo "============================================"
    echo "  $DISTRO_NAME — ISO Build Script"
    echo "  Base: Fedora $RELEASEVER"
    echo "  Profile: $PROFILE"
    echo "============================================"
    echo ""

    preflight
    install_deps
    prepare_kickstart
    build_iso
    post_build
    cleanup

    log "Build process complete!"
}

main "$@"
