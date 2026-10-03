#!/usr/bin/env bash
# =============================================================================
# download-iso.sh — fetch, reassemble and verify a KAAL OS ISO from GitHub
# Releases. The ISO is published as several parts, each under GitHub's 2 GiB
# per-file limit.
#
# Usage:
#   bash download-iso.sh                 # newest release
#   bash download-iso.sh v0.0.1-testiso  # a specific release tag
#
# What it does:
#   1. reads MANIFEST.txt from the release
#   2. downloads every part (resumable — safe to re-run)
#   3. verifies each part against SHA256SUMS
#   4. concatenates the parts into the ISO
#   5. verifies the ISO's own SHA-256
# Nothing is installed. Uses only curl and sha256sum (or shasum on macOS).
# =============================================================================
set -euo pipefail

REPO="pujariseema93-beep/kaal-os"
TAG="${1:-latest}"

if [ "$TAG" = "latest" ]; then
    echo "==> Looking up the newest release..."
    TAG=$(curl -fsSL --retry 3 "https://api.github.com/repos/$REPO/releases" \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
    if [ -z "$TAG" ]; then
        echo "ERROR: could not find a release. Pass a tag, e.g.:"
        echo "  bash download-iso.sh v0.0.1-testiso"
        exit 1
    fi
fi

BASE="${KAAL_BASE_URL:-https://github.com/$REPO/releases/download/$TAG}"
WORKDIR="${WORKDIR:-$PWD/kaal-os-iso}"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "==> Release: $TAG"
echo "==> Fetching MANIFEST.txt..."
curl -fL --retry 5 --retry-delay 3 -o MANIFEST.txt "$BASE/MANIFEST.txt"

ISO_NAME=$(sed -n 's/^iso=//p' MANIFEST.txt)
ISO_SHA=$(sed -n 's/^sha256=//p' MANIFEST.txt)
PARTS=$(sed -n 's/^part=//p' MANIFEST.txt)
if [ -z "$ISO_NAME" ] || [ -z "$ISO_SHA" ] || [ -z "$PARTS" ]; then
    echo "ERROR: MANIFEST.txt is missing or malformed."
    exit 1
fi
PART_COUNT=$(printf '%s\n' "$PARTS" | wc -l | tr -d ' ')
echo "==> ISO: $ISO_NAME ($PART_COUNT parts)"

echo "==> Downloading parts..."
for p in $PARTS; do
    if [ -f "$p" ]; then
        echo "    $p (already present, skipping)"
        continue
    fi
    echo "    $p"
    curl -fL --retry 5 --retry-delay 3 -C - -o "$p" "$BASE/$p"
done

echo "==> Verifying part checksums..."
curl -fL --retry 5 --retry-delay 3 -o SHA256SUMS "$BASE/SHA256SUMS"
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c SHA256SUMS
else
    shasum -a 256 -c SHA256SUMS
fi

echo "==> Reassembling the ISO..."
printf '%s\n' "$PARTS" | xargs cat > "$ISO_NAME"

echo "==> Verifying the ISO checksum..."
if command -v sha256sum >/dev/null 2>&1; then
    printf '%s  %s\n' "$ISO_SHA" "$ISO_NAME" | sha256sum -c -
else
    printf '%s  %s\n' "$ISO_SHA" "$ISO_NAME" | shasum -a 256 -c -
fi

ls -lh "$ISO_NAME"
echo ""
echo "====================================================================="
echo " DONE — $ISO_NAME is verified and ready."
echo ""
echo " Write it to a USB stick (16 GB recommended). Replace /dev/sdX with"
echo " your device — check it first with 'lsblk':"
echo ""
echo "   sudo dd if=\"$ISO_NAME\" of=/dev/sdX bs=4M status=progress oflag=sync"
echo ""
echo " On Windows, use Rufus (rufus.ie) or balenaEtcher instead."
echo "====================================================================="
