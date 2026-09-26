#!/bin/bash
# =============================================================================
# make-obs-package.sh — Assemble the KAAL OS OBS build package
# =============================================================================
# Creates an osc working directory for the KAAL OS live ISO image build on
# the openSUSE Build Service. See docs/OBS_BUILD_GUIDE.md for the full
# walkthrough — this script only assembles the files.
#
# What ends up in the package:
#   config.kiwi   — kiwi image description (from obs/config.kiwi)
#   config.sh     — in-image customization script
#   root/         — overlay: the file trees of the 7 KAAL packages
#                    (distro-bootloader, distro-iso-builder, distro-calamares,
#                     distro-hardware, kaal-spaces, kaal-visual, kaal-security)
#
# Usage:
#   ./make-obs-package.sh <osc-workdir>
#
#   <osc-workdir>   an existing osc checkout of your OBS package, e.g.:
#                     osc -A https://api.opensuse.org co home:YOURNAME:kaal kaal-os-live
#                     ./make-obs-package.sh home:YOURNAME:kaal/kaal-os-live
# =============================================================================
set -euo pipefail

OBS_DIR="${1:?Usage: make-obs-package.sh <osc-workdir>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_PACKAGES="$HERE/../.."   # script lives at packages/distro-iso-builder/obs/ -> up 2 = packages/

if [ ! -d "$OBS_DIR" ]; then
    echo "ERROR: $OBS_DIR does not exist."
    echo "Create it first with:  osc co home:YOURNAME:kaal kaal-os-live"
    exit 1
fi
if [ ! -d "$REPO_PACKAGES/distro-bootloader" ]; then
    echo "ERROR: cannot find the packages/ tree at $REPO_PACKAGES"
    exit 1
fi

echo "== Assembling KAAL OS OBS package in: $OBS_DIR =="

# ---- 1. kiwi description + config script ------------------------------------
cp "$HERE/config.kiwi" "$OBS_DIR/config.kiwi"
cp "$HERE/config.sh"    "$OBS_DIR/config.sh"
chmod +x "$OBS_DIR/config.sh"

# ---- 2. root/ overlay from the 7 KAAL packages ------------------------------
rm -rf "$OBS_DIR/root"
mkdir -p "$OBS_DIR/root"

for pkg in distro-bootloader distro-iso-builder distro-calamares \
           distro-hardware kaal-spaces kaal-visual kaal-security; do
    src="$REPO_PACKAGES/$pkg"
    if [ ! -d "$src" ]; then
        echo "ERROR: missing package directory: $src"
        exit 1
    fi
    # Copy only the system file trees (etc/, usr/, boot/, opt/),
    # skipping docs, READMEs and installer scripts.
    for subtree in etc usr boot opt var; do
        if [ -d "$src/$subtree" ]; then
            mkdir -p "$OBS_DIR/root/$subtree"
            cp -a "$src/$subtree/." "$OBS_DIR/root/$subtree/"
            echo "  staged: $pkg/$subtree"
        fi
    done
done

# ---- 3. Calamares configuration → /etc/calamares -----------------------------
# The Calamares files live at the package root (settings.conf, modules/,
# branding/) rather than under etc/, so they need explicit mapping.
if [ -f "$REPO_PACKAGES/distro-calamares/settings.conf" ]; then
    mkdir -p "$OBS_DIR/root/etc/calamares"
    cp "$REPO_PACKAGES/distro-calamares/settings.conf" \
       "$OBS_DIR/root/etc/calamares/settings.conf"
    cp -a "$REPO_PACKAGES/distro-calamares/modules" \
          "$OBS_DIR/root/etc/calamares/modules" 2>/dev/null || true
    cp -a "$REPO_PACKAGES/distro-calamares/branding" \
          "$OBS_DIR/root/etc/calamares/branding" 2>/dev/null || true
    echo "  staged: distro-calamares → /etc/calamares"
fi
# kaal-spaces ships extra Calamares modules (e.g. space-select) under
# calamares/modules/ — merge them into the same /etc/calamares tree.
if [ -d "$REPO_PACKAGES/kaal-spaces/calamares/modules" ]; then
    mkdir -p "$OBS_DIR/root/etc/calamares/modules"
    cp -a "$REPO_PACKAGES/kaal-spaces/calamares/modules/." \
          "$OBS_DIR/root/etc/calamares/modules/"
    echo "  staged: kaal-spaces calamares modules → /etc/calamares/modules"
fi

# ---- 4. Summary --------------------------------------------------------------
echo
echo "== Done. Package contents: =="
find "$OBS_DIR" -maxdepth 2 -not -path "*/.osc*" | sort | head -30
echo
echo "Next steps (see docs/OBS_BUILD_GUIDE.md):"
echo "  cd $OBS_DIR"
echo "  osc addremove"
echo "  osc ci -m 'KAAL OS live ISO update'"
