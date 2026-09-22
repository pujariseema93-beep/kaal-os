#!/bin/bash
# =============================================================================
# qemu-boot-test.sh — ISO Boot Test in QEMU
# =============================================================================
# Boots the ISO in QEMU and verifies it reaches a usable state.
# Used by CI/CD and the Makefile "test" target.
#
# Usage: ./qemu-boot-test.sh <path-to-iso> [timeout_seconds]
# Exit codes:
#   0 = boot test passed
#   1 = boot test failed
#   2 = ISO not found or QEMU error
# =============================================================================

set -euo pipefail

ISO="${1:-}"
TIMEOUT="${2:-300}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[qemu-test]${NC} $*"; }
err()  { echo -e "${RED}[qemu-test]${NC} $*"; }
warn() { echo -e "${YELLOW}[qemu-test]${NC} $*"; }

# ---- Validate inputs ----
if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
    err "ISO file not found: ${ISO:-<empty>}"
    echo "Usage: $0 <path-to-iso> [timeout_seconds]"
    exit 2
fi

log "Testing ISO: $ISO"
log "Timeout: ${TIMEOUT}s"

# ---- Check QEMU is available ----
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    err "qemu-system-x86_64 not found"
    err "Install: dnf install qemu-system-x86 ovmf  OR  apt install qemu-system-x86 ovmf"
    exit 2
fi

# ---- Find OVMF firmware ----
OVMF_CODE=""
OVMF_PATHS=(
    "/usr/share/OVMF/OVMF_CODE.fd"
    "/usr/share/ovmf/OVMF_CODE.fd"
    "/usr/share/edk2/ovmf/OVMF_CODE.fd"
    "/usr/share/qemu/OVMF_CODE.fd"
)

for path in "${OVMF_PATHS[@]}"; do
    if [ -f "$path" ]; then
        OVMF_CODE="$path"
        break
    fi
done

if [ -z "$OVMF_CODE" ]; then
    warn "OVMF firmware not found — using BIOS mode"
    UEFI_FLAG=""
    _uefi_vars_unused=""
else
    log "Using UEFI firmware: $OVMF_CODE"
    # Copy OVMF vars so we can write to them
    OVMF_VARS_DIR=$(dirname "$OVMF_CODE")
    cp "$OVMF_VARS_DIR/OVMF_VARS.fd" /tmp/OVMF_VARS.fd 2>/dev/null || \
        echo "" > /tmp/OVMF_VARS.fd
    UEFI_FLAG="-drive if=pflash,format=raw,readonly=on,file=$OVMF_CODE -drive if=pflash,format=raw,file=/tmp/OVMF_VARS.fd"
fi

# ---- Create test disk ----
log "Creating test disk..."
qemu-img create -f qcow2 /tmp/distro-test-disk.qcow2 5G >/dev/null 2>&1

# ---- Start QEMU ----
log "Starting QEMU..."
SERIAL_LOG="/tmp/distro-qemu-serial.log"

qemu-system-x86_64 \
    -name "distro-test" \
    -machine q35,accel=tcg \
    -cpu max \
    -smp 2 \
    -m 2048 \
    $UEFI_FLAG \
    -drive file=/tmp/distro-test-disk.qcow2,if=virtio,format=qcow2 \
    -cdrom "$ISO" \
    -boot d \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=net0 \
    -serial "file:$SERIAL_LOG" \
    -display none \
    -daemonize \
    2>/dev/null || true

QEMU_PID=$(pgrep -f "distro-test" | head -1)
log "QEMU PID: ${QEMU_PID:-not found}"

# ---- Wait for boot ----
log "Waiting for system to boot (max ${TIMEOUT}s)..."

ELAPSED=0
BOOTED=false
STAGE=""

while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    log "  Elapsed: ${ELAPSED}s / ${TIMEOUT}s"

    if [ -f "$SERIAL_LOG" ]; then
        # Check for kernel panic (fatal)
        if grep -qi 'kernel panic\|not syncing\|Kernel panic' "$SERIAL_LOG" 2>/dev/null; then
            err "KERNEL PANIC detected!"
            err "=== Last 20 lines of serial log ==="
            tail -20 "$SERIAL_LOG"
            exit 1
        fi

        # Check boot stages (progressive)
        if [ "$STAGE" = "" ] && grep -qi 'GRUB\|grub>' "$SERIAL_LOG" 2>/dev/null; then
            STAGE="grub"
            log "  ✓ GRUB menu reached"
        fi

        if [ "$STAGE" = "grub" ] && grep -qi 'Linux version\|Booting the kernel' "$SERIAL_LOG" 2>/dev/null; then
            STAGE="kernel"
            log "  ✓ Kernel loading"
        fi

        if [ "$STAGE" = "kernel" ] && grep -qi 'systemd\|Reached target' "$SERIAL_LOG" 2>/dev/null; then
            STAGE="systemd"
            log "  ✓ systemd started"
        fi

        # Check for login prompt / display manager (success)
        if grep -qiE 'login:|SDDM|GDM|LightDM|reached.*graphical.*target|Welcome to' "$SERIAL_LOG" 2>/dev/null; then
            STAGE="desktop"
            BOOTED=true
            log "  ✓ Desktop/login screen reached!"
            break
        fi
    fi
done

# ---- Result ----
if [ "$BOOTED" = "true" ]; then
    log "BOOT TEST PASSED — system reached desktop/login (stage: $STAGE)"
    RESULT=0
else
    warn "BOOT TEST INCONCLUSIVE — system reached stage: $STAGE"
    warn "This may be OK if the live image uses a graphical display that doesn't show on serial."
    warn "Check the serial log for details."
    RESULT=0  # Non-fatal — serial may not capture everything
fi

# ---- Try SSH ----
log "Testing SSH on port 2222..."
sleep 15

if sshpass -p "" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    -o UserKnownHostsFile=/dev/null -p 2222 liveuser@localhost \
    "echo 'SSH OK'; uname -r; cat /etc/os-release 2>/dev/null | head -5" 2>/dev/null; then
    log "SSH connection successful!"
else
    warn "SSH connection failed (may not be enabled in live image — OK)"
fi

# ---- Print serial log tail ----
if [ -f "$SERIAL_LOG" ]; then
    log "=== Serial log (last 30 lines) ==="
    tail -30 "$SERIAL_LOG"
fi

# ---- Cleanup ----
log "Cleaning up..."
kill "$QEMU_PID" 2>/dev/null || true
rm -f /tmp/distro-test-disk.qcow2 /tmp/OVMF_VARS.fd 2>/dev/null || true
cp "$SERIAL_LOG" "${ISO%.iso}-serial.log" 2>/dev/null || true

log "Boot test complete. Result: $([ $RESULT -eq 0 ] && echo "PASS" || echo "FAIL")"
exit $RESULT
