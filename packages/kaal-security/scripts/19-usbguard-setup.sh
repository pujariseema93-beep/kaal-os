#!/usr/bin/env bash
# =============================================================================
# 19-usbguard-setup.sh — KAAL OS USB device control
# =============================================================================
# Runs in the Calamares chroot. Generates a USBGuard policy that:
#   - allows every device present at install time (the user's own hardware)
#   - allows human-interface devices (keyboards, mice, tablets) generically
#   - blocks NEW storage / network / arbitrary devices until the user
#     authorizes them (usbguard-dbus exposes an applet prompt)
#
# Why generate instead of shipping a static policy: device IDs differ per
# machine. A static allowlist would either block the user's own keyboard
# (bricking the session) or allow everything (useless).
# =============================================================================

set -euo pipefail

log() { echo "[kaal-security] $*"; }

if ! command -v usbguard >/dev/null 2>&1; then
    echo "[kaal-security] usbguard not installed — skipping USB control" >&2
    exit 0
fi

RULES_FILE="/etc/usbguard/rules.conf"
mkdir -p /etc/usbguard

# ---------------------------------------------------------------------------
# 1. Generate the base policy from devices present right now
# ---------------------------------------------------------------------------
POLICY=""
if usbguard generate-policy >/tmp/kaal-usbgen.policy 2>/dev/null; then
    # generate-policy exits 0 even on an empty bus — sanity check
    if [ -s /tmp/kaal-usbgen.policy ]; then
        POLICY="$(cat /tmp/kaal-usbgen.policy)"
    fi
fi

# ---------------------------------------------------------------------------
# 2. Fallback: HID-only policy (install-time device scan failed)
# ---------------------------------------------------------------------------
if [ -z "$POLICY" ]; then
    log "device scan produced nothing — using HID-only fallback policy"
    cat > "$RULES_FILE" << 'HIDEOF'
# KAAL OS — fallback USBGuard policy (HID only)
# Allow keyboards / mice / tablets on any port, block everything else
allow with-interface equals { 03:00:01 03:01:01 03:00:00 }
allow with-interface 03:00:02
HIDEOF
else
    printf '%s\n' \
        "# KAAL OS USBGuard policy (generated at install by 19-usbguard-setup.sh)" \
        "# Devices present at install time are allowed; new storage/network" \
        "# devices require user authorization. HID is always allowed." \
        "" \
        "# ---- Generic HID allowance (any keyboard/mouse, any port) ----" \
        "allow with-interface equals { 03:00:01 03:01:01 03:00:00 }" \
        "allow with-interface 03:00:02" \
        "" \
        "# ---- Devices present at install time (this machine's own hardware) ----" \
        "$POLICY" > "$RULES_FILE"
fi

chmod 0600 "$RULES_FILE"
chown root:root "$RULES_FILE" 2>/dev/null || true
rm -f /tmp/kaal-usbgen.policy

# ---------------------------------------------------------------------------
# 3. Daemon configuration — explicit, no surprises
# ---------------------------------------------------------------------------
if [ -f /etc/usbguard/usbguard-daemon.conf ]; then
    # New unknown devices are blocked and reported via dbus (user gets a prompt
    # from usbguard-dbus); the policy above decides who is pre-authorized.
    sed -i 's/^ImplicitPolicyTarget=.*/ImplicitPolicyTarget=block/' \
        /etc/usbguard/usbguard-daemon.conf 2>/dev/null || true
    grep -q '^ImplicitPolicyTarget=' /etc/usbguard/usbguard-daemon.conf 2>/dev/null || \
        echo 'ImplicitPolicyTarget=block' >> /etc/usbguard/usbguard-daemon.conf
fi

# ---------------------------------------------------------------------------
# 4. Enable
# ---------------------------------------------------------------------------
systemctl enable usbguard.service >/dev/null 2>&1 || true
log "USBGuard enabled: own hardware + HID allowed, new devices need approval"

exit 0
