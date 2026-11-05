#!/bin/bash
# =============================================================================
# ci-kiwi-build.sh — runs INSIDE the fedora:44 container, not on the runner.
# =============================================================================
# Invoked by .github/workflows/build-iso-kiwi.yml as:
#   docker run --rm --privileged -v "$PWD:/workspace" -w /workspace \
#     fedora:44 bash /workspace/scripts/ci-kiwi-build.sh
#
# Kept as a file rather than inline in the workflow so it can be syntax-checked
# and read like normal code. The workflow previously used
# addnab/docker-run-action, which received an empty `image` input and tried to
# pull a mangled tag ("pull access denied for 916ccf"); calling docker directly
# removes that dependency entirely.
# =============================================================================
set -euo pipefail

echo "=== kiwi build: environment ==="
cat /etc/fedora-release || true
df -h / | tail -1

echo "=== installing kiwi ==="
# "kiwi-system-dependencies" is the openSUSE package name and does not exist on
# Fedora (run #5: "No match for argument: kiwi-system-dependencies"). Fedora
# splits the same build dependencies into kiwi-systemdeps-* metapackages, and
# which ones exist varies by release — so log what is actually available and
# install whatever resolves, rather than pinning one name and failing.
dnf install -y kiwi-cli

echo "--- available kiwi packages ---"
dnf list --available 'kiwi*' 2>/dev/null | awk '{print $1}' | sort -u | head -40 || true

for p in kiwi-systemdeps-iso kiwi-systemdeps-filesystems kiwi-systemdeps-core \
         kiwi-systemdeps-bootloaders kiwi-systemdeps-disk-images kiwi-systemdeps; do
    if dnf install -y "$p" >/dev/null 2>&1; then
        echo "installed: $p"
    else
        echo "not available, skipped: $p"
    fi
done

echo "--- kiwi-ng version ---"
# Check for the BINARY, not its exit code. `kiwi-ng --version` prints
# "KIWI (next generation) version 11.1.1" and then exits non-zero, so an
# `|| error` guard here reported "kiwi-ng is not installed" on a machine where
# it had just installed perfectly (run #6).
if ! command -v kiwi-ng >/dev/null 2>&1; then
    echo "::error::kiwi-ng is not on PATH after installing kiwi-cli"
    exit 1
fi
kiwi-ng --version 2>&1 | head -3 || true

echo "=== staging the seven KAAL packages into kiwi's root overlay ==="
# kiwi copies everything under <description>/root/ into the image, so the
# packages are staged there. Inside the image they appear at /kaal-staging,
# which is what config.sh reads.
DESC=/workspace/packages/distro-iso-builder/kiwi

# Stage to /tmp FIRST, then move into place. The overlay lives at
# $DESC/root/, which is itself inside packages/distro-iso-builder/ — so copying
# that package straight into it recursed into itself (run #8:
# "cp: cannot copy a directory ... into itself").
STAGE_TMP=/tmp/kaal-staging
rm -rf "$STAGE_TMP" "$DESC/root"
mkdir -p "$STAGE_TMP"

for pkg in distro-bootloader distro-calamares distro-hardware \
           distro-iso-builder kaal-monitor kaal-security \
           kaal-spaces kaal-visual; do
    if [ -d "/workspace/packages/$pkg" ]; then
        cp -r "/workspace/packages/$pkg" "$STAGE_TMP/"
    else
        echo "::warning::package directory missing: packages/$pkg"
    fi
done

mkdir -p "$DESC/root"
cp -r "$STAGE_TMP" "$DESC/root/kaal-staging"
rm -rf "$STAGE_TMP"

echo "staged into the kiwi overlay:"
ls "$DESC/root/kaal-staging/"

chmod +x "$DESC/config.sh"

echo "=== kiwi-ng system build ==="
rm -rf /workspace/kiwi-out
# --debug: when schema validation fails, kiwi prints only a summary by default
# ("Failed to validate schema and/or schematron rules"). With --debug it names
# the offending element, which turns a guessing game into a reading exercise.
kiwi-ng --debug system build \
    --description "$DESC" \
    --target-dir /workspace/kiwi-out

echo "=== result ==="
find /workspace/kiwi-out -name '*.iso' -type f -printf '%p  %s bytes\n' || true
ISO=$(find /workspace/kiwi-out -name '*.iso' -type f | head -1)

# Leave the checkout clean so the staged overlay is never committed.
rm -rf "$DESC/root"

if [ -z "$ISO" ]; then
    echo "::error::kiwi produced no ISO"
    echo "--- kiwi-out tree (depth 2) ---"
    find /workspace/kiwi-out -maxdepth 2 2>/dev/null | head -40
    exit 1
fi

sha256sum "$ISO" | tee "$ISO.sha256"
echo "=== kiwi build complete ==="
