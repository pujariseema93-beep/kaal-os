#!/usr/bin/env bash
# =============================================================================
# codespace-boot-test.sh — Boot a KAAL OS ISO in a GitHub Codespace and view it
# in your browser (noVNC), no virtualization needed.
#
# Usage:
#   bash scripts/codespace-boot-test.sh              # minimal test ISO (default)
#   bash scripts/codespace-boot-test.sh full         # full KAAL OS live ISO (~6.8 GB)
#   bash scripts/codespace-boot-test.sh minimal      # minimal test ISO (explicit)
#   bash scripts/codespace-boot-test.sh <artifact>   # any artifact name
#
# Notes:
#   - Codespaces have no KVM, so the ISO boots under software emulation.
#     That is SLOW: the minimal ISO takes ~15-40 min, the full ISO can take
#     30-60+ min to reach the desktop. This is a "does it boot?" proof, not a
#     speed test.
#   - The full ISO is a ~6.8 GB download; make sure the Codespace has room.
#   - Safe to re-run any time: it stops any previous run of itself first.
# =============================================================================
set -euo pipefail

REPO="pujariseema93-beep/kaal-os"
WORKDIR="/tmp/kaal-boot-test"
VNC_PORT=6080

# --- Which ISO to test -------------------------------------------------------
# The first argument (or $ARTIFACT_NAME) picks the artifact. Friendly aliases:
# "minimal" and "full" / "live". Anything else is used as a literal artifact name.
case "${1:-${ARTIFACT_NAME:-minimal}}" in
    ""|minimal|min) ARTIFACT_NAME="kaal-minimal-test-iso" ;;
    full|live)      ARTIFACT_NAME="kaal-os-live-iso" ;;
    *)              ARTIFACT_NAME="${1:-${ARTIFACT_NAME:-kaal-minimal-test-iso}}" ;;
esac
ISO_PATH="$WORKDIR/${ARTIFACT_NAME}.iso"

# Stop any previous run of this script, so it is safe to re-run any time
pkill -f "qemu-system-x86_64.*kaal-boot-test" 2>/dev/null || true
pkill -f "websockify.*$VNC_PORT" 2>/dev/null || true
sleep 2

echo "==> [1/4] Installing QEMU + noVNC (takes a minute)..."
sudo apt-get update -qq
sudo apt-get install -y -qq qemu-system-x86 novnc websockify >/dev/null

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "==> [2/4] Fetching '$ARTIFACT_NAME' from the latest build artifact..."
if [ ! -f "$ISO_PATH" ]; then
    RUN_ID=$(gh api "repos/$REPO/actions/artifacts?per_page=50" \
        --jq "[.artifacts[] | select(.name==\"$ARTIFACT_NAME\" and .expired==false) | .workflow_run.id][0]")
    if [ -z "${RUN_ID:-}" ] || [ "$RUN_ID" = "null" ]; then
        echo ""
        echo "ERROR: no fresh '$ARTIFACT_NAME' artifact found (they expire after ~7 days)."
        echo "Fix: push any commit to the repo to trigger a new build, wait for it to"
        echo "finish, then re-run this script."
        exit 1
    fi
    rm -rf "$WORKDIR/iso"
    gh run download -R "$REPO" "$RUN_ID" -n "$ARTIFACT_NAME" -D "$WORKDIR/iso"
    mv "$WORKDIR"/iso/*.iso "$ISO_PATH"
    rm -rf "$WORKDIR/iso"
fi
ls -lh "$ISO_PATH"

echo "==> [3/4] Starting QEMU (software emulation — slow but real)..."
# Give the VM half the machine's RAM, capped at 4 GB. Override with VM_MEM=...
FREE_MB=$(free -m | awk '/^Mem:/{print $2}')
VM_MEM="${VM_MEM:-$(( FREE_MB / 2 ))}"; [ "$VM_MEM" -gt 4096 ] && VM_MEM=4096
# Use the machine's cores, capped at 4 (software emulation benefits from cores).
SMP="${SMP:-$(nproc)}"; [ "$SMP" -gt 4 ] && SMP=4
echo "    VM memory: ${VM_MEM} MB, CPUs: ${SMP}"

qemu-system-x86_64 \
    -machine q35 \
    -accel tcg,thread=multi \
    -m "$VM_MEM" \
    -smp "$SMP" \
    -cdrom "$ISO_PATH" \
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
echo " DONE. Testing artifact: $ARTIFACT_NAME"
echo ""
echo " Now open the viewer:"
echo "   1. In the Codespace window, open the PORTS tab (bottom panel)."
echo "   2. Port $VNC_PORT appears as 'Forwarded' — click the globe icon"
echo "      (Open in Browser)."
echo "   3. Click 'Connect' in the noVNC page."
echo ""
echo " You should see the KAAL OS boot screen, then the desktop."
echo " Boot is slow (software emulation): minimal ~15-40 min, full ISO 30-60+ min."
echo ""
echo " If you land on a text login instead of a desktop: log in as 'liveuser'"
echo " (empty password), then run:  sudo systemctl isolate graphical.target"
echo ""
echo " To stop everything later:"
echo "   kill \$(cat $WORKDIR/qemu.pid) \$(cat $WORKDIR/websockify.pid)"
echo "====================================================================="
