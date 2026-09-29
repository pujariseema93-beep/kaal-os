#!/usr/bin/env bash
# =============================================================================
# codespace-boot-test.sh — Boot the KAAL OS minimal test ISO in a GitHub
# Codespace and view it in your browser (noVNC), no virtualization needed.
#
# Run it from a Codespace terminal:
#   bash scripts/codespace-boot-test.sh
#
# Notes:
#   - Codespaces have no KVM, so the ISO boots under software emulation.
#     That is SLOW: expect roughly 15-40 minutes to reach the desktop.
#     This is a "does it boot?" proof, not a speed test.
#   - Needs 4 GB+ of ISO download; free Codespace hours are plenty for this.
# =============================================================================
set -euo pipefail

REPO="pujariseema93-beep/kaal-os"
ARTIFACT_NAME="kaal-minimal-test-iso"
ISO_NAME="KAAL_OS_minimal_test_x86_64.iso"
WORKDIR="/tmp/kaal-boot-test"
VNC_PORT=6080

echo "==> [1/4] Installing QEMU + noVNC (takes a minute)..."
sudo apt-get update -qq
sudo apt-get install -y -qq qemu-system-x86 novnc websockify >/dev/null

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "==> [2/4] Fetching the ISO from the latest build artifact..."
if [ ! -f "$ISO_NAME" ]; then
    RUN_ID=$(gh api "repos/$REPO/actions/artifacts?per_page=50" \
        --jq "[.artifacts[] | select(.name==\"$ARTIFACT_NAME\" and .expired==false) | .workflow_run.id][0]")
    if [ -z "${RUN_ID:-}" ] || [ "$RUN_ID" = "null" ]; then
        echo ""
        echo "ERROR: no fresh '$ARTIFACT_NAME' artifact found (they expire after ~7 days)."
        echo "Fix: push any commit to the repo to trigger a new build, wait ~15 min,"
        echo "then re-run this script."
        exit 1
    fi
    gh run download -R "$REPO" "$RUN_ID" -n "$ARTIFACT_NAME" -D "$WORKDIR/iso"
    mv "$WORKDIR"/iso/*.iso "$WORKDIR/$ISO_NAME"
    rm -rf "$WORKDIR/iso"
fi
ls -lh "$ISO_NAME"

echo "==> [3/4] Starting QEMU (software emulation — slow but real)..."
# Give the VM half the machine's RAM, capped at 4 GB.
FREE_MB=$(free -m | awk '/^Mem:/{print $2}')
VM_MEM=$(( FREE_MB / 2 )); [ "$VM_MEM" -gt 4096 ] && VM_MEM=4096
echo "    VM memory: ${VM_MEM} MB"

qemu-system-x86_64 \
    -machine q35 \
    -accel tcg,thread=multi \
    -m "$VM_MEM" \
    -smp 2 \
    -cdrom "$WORKDIR/$ISO_NAME" \
    -boot d \
    -vga std \
    -display none \
    -vnc 127.0.0.1:0 &
echo $! > "$WORKDIR/qemu.pid"

echo "==> [4/4] Starting noVNC web viewer on port $VNC_PORT..."
websockify --web /usr/share/novnc "$VNC_PORT" 127.0.0.1:5900 > "$WORKDIR/websockify.log" 2>&1 &
echo $! > "$WORKDIR/websockify.pid"

sleep 2
echo ""
echo "====================================================================="
echo " DONE. Now open the viewer:"
echo "   1. In the Codespace window, open the PORTS tab (bottom panel)."
echo "   2. Port $VNC_PORT appears as 'Forwarded' — click the globe icon"
echo "      (Open in Browser)."
echo "   3. Click 'Connect' in the noVNC page."
echo ""
echo " You should see the KAAL OS boot screen, then the desktop."
echo " Boot is slow (software emulation) — 15 to 40 minutes is normal."
echo ""
echo " To stop everything later:"
echo "   kill \$(cat $WORKDIR/qemu.pid) \$(cat $WORKDIR/websockify.pid)"
echo "====================================================================="
