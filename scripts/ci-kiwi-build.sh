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
rm -rf "$DESC/root"
mkdir -p "$DESC/root/kaal-staging"

for pkg in distro-bootloader distro-calamares distro-hardware \
           distro-iso-builder kaal-monitor kaal-security \
           kaal-spaces kaal-visual; do
    if [ -d "/workspace/packages/$pkg" ]; then
        cp -r "/workspace/packages/$pkg" "$DESC/root/kaal-staging/"
    else
        echo "::warning::package directory missing: packages/$pkg"
    fi
done
echo "staged:"
ls "$DESC/root/kaal-staging/"

chmod +x "$DESC/config.sh"

echo "=== kiwi-ng system build ==="
rm -rf /workspace/kiwi-out
kiwi-ng system build \
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
