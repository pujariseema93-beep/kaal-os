#!/usr/bin/env bash
# =============================================================================
# 18-security-hardening.sh — KAAL OS baseline OS hardening
# =============================================================================
# Runs in the Calamares chroot (target system) as part of the post-install
# chain, after unpackfs has copied the live filesystem — so the staged
# configs at /usr/share/kaal-security/config/ exist in the target.
#
# Applied:
#   1. Kernel sysctl hardening profile
#   2. SELinux enforcing (idempotent — the live ISO and installed system
#      both boot enforcing; this pins the config and schedules a relabel
#      for files laid down during install)
#   3. Firewall: ssh removed from the default zone
#   4. sshd disabled (Security Space enables it on demand)
#   5. auditd with watch rules
#   6. Password quality policy
#
# This script NEVER changes: DE selection, spaces profiles, visual theme.
# Spaces may not override anything set here (see docs/SECURITY.md).
# =============================================================================

set -euo pipefail

SRC="/usr/share/kaal-security/config"
log() { echo "[kaal-security] $*"; }

# ---------------------------------------------------------------------------
# 0. Preconditions — fail soft if the staging tree is missing (e.g. someone
#    runs this outside the installer), but say so loudly.
# ---------------------------------------------------------------------------
if [ ! -d "$SRC" ]; then
    echo "[kaal-security] WARNING: $SRC not found — hardening configs unavailable." >&2
    echo "[kaal-security] Refusing to half-harden; exiting 0 so install continues." >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Kernel sysctl hardening
# ---------------------------------------------------------------------------
if [ -f "$SRC/sysctl-70-kaal-security.conf" ]; then
    install -D -m 0644 "$SRC/sysctl-70-kaal-security.conf" \
        /etc/sysctl.d/70-kaal-security.conf
    # Apply now where possible (chroot may not allow all writes; that is
    # fine — the file is read at every boot anyway)
    sysctl --system >/dev/null 2>&1 || true
    log "kernel hardening profile installed (/etc/sysctl.d/70-kaal-security.conf)"
fi

# ---------------------------------------------------------------------------
# 2. SELinux — pin enforcing (Fedora parity, live and installed)
# ---------------------------------------------------------------------------
if [ -f /etc/selinux/config ]; then
    sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
    grep -q '^SELINUXTYPE=' /etc/selinux/config 2>/dev/null || \
        echo 'SELINUXTYPE=targeted' >> /etc/selinux/config
    # Files laid down by the installer inherit default types; relabel on
    # first boot so everything is correctly labeled before enforcing mode
    touch /.autorelabel
    log "SELinux set to enforcing with first-boot relabel"
else
    echo "[kaal-security] WARNING: /etc/selinux/config missing — skipping SELinux" >&2
fi

# ---------------------------------------------------------------------------
# 3. Firewall — SSH out of the default zone
# ---------------------------------------------------------------------------
if command -v firewall-offline-cmd >/dev/null 2>&1; then
    # Remove ssh if a previous layer opened it
    firewall-offline-cmd --remove-service=ssh >/dev/null 2>&1 || true
    log "firewalld default zone: ssh removed"
fi
systemctl enable firewalld >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# 4. sshd — installed but not running
# ---------------------------------------------------------------------------
systemctl disable sshd.service >/dev/null 2>&1 || true
systemctl disable sshd.socket >/dev/null 2>&1 || true
log "sshd disabled (Security Space enables it on demand)"

# ---------------------------------------------------------------------------
# 5. auditd with watch rules
# ---------------------------------------------------------------------------
if [ -f "$SRC/audit-70-kaal.rules" ]; then
    install -D -m 0640 "$SRC/audit-70-kaal.rules" \
        /etc/audit/rules.d/70-kaal.rules
    chown root:root /etc/audit/rules.d/70-kaal.rules 2>/dev/null || true
    systemctl enable auditd >/dev/null 2>&1 || true
    log "auditd enabled with identity/sudoers/selinux watch rules"
fi

# ---------------------------------------------------------------------------
# 6. Password quality
# ---------------------------------------------------------------------------
if [ -f "$SRC/pwquality-kaal.conf" ]; then
    install -D -m 0644 "$SRC/pwquality-kaal.conf" \
        /etc/security/pwquality.conf.d/kaal.conf
    log "password quality policy installed (minlen=10, minclass=3)"
fi

log "hardening complete"
exit 0
