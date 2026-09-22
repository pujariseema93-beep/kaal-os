#!/usr/bin/env bash
# =============================================================================
# 20-antivirus-setup.sh — KAAL OS ClamAV integration
# =============================================================================
# Runs in the Calamares chroot. Baseline philosophy:
#
#   - Signature UPDATES always on (clamav-freshclam — lightweight)
#   - On-DEMAND scanning always available (clamscan / kaal-antivirus scan)
#   - ON-ACCESS scanning OFF by default — it taxes every file read, which
#     is the wrong trade for a gaming distro. The Security Space turns it
#     on; `sudo kaal-antivirus enable-on-access` turns it on anywhere.
#
# Linux desktop malware is rare; the real defenses are SELinux, USBGuard
# and the hardened kernel (scripts 18-19). ClamAV here is mainly for
# scanning files KAAL users share with Windows machines (dual-boot,
# email, downloads).
# =============================================================================

set -euo pipefail

log() { echo "[kaal-security] $*"; }

# ---------------------------------------------------------------------------
# 0. Preconditions
# ---------------------------------------------------------------------------
if ! command -v clamscan >/dev/null 2>&1; then
    echo "[kaal-security] clamav not installed — skipping antivirus setup" >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. clamd configuration (/etc/clamd.d/scan.conf)
# ---------------------------------------------------------------------------
CLAMD_CONF="/etc/clamd.d/scan.conf"
if [ -f "$CLAMD_CONF" ]; then
    # The shipped config is an Example — make it usable
    sed -i 's/^Example$/#Example/' "$CLAMD_CONF"
    # Local socket for clamdscan / clamonacc
    if ! grep -q '^LocalSocket' "$CLAMD_CONF"; then
        echo 'LocalSocket /run/clamd.scan/clamd.sock' >> "$CLAMD_CONF"
    fi
    # Constrain memory: drop the signature cache at 256 MB instead of default
    if ! grep -q '^ConcurrentDatabaseReload no' "$CLAMD_CONF"; then
        echo 'ConcurrentDatabaseReload no' >> "$CLAMD_CONF"
    fi
    chmod 0644 "$CLAMD_CONF"
    log "clamd configured (LocalSocket, low-memory reload)"
fi

# ---------------------------------------------------------------------------
# 2. Signature updates — always on
# ---------------------------------------------------------------------------
systemctl enable clamav-freshclam.service >/dev/null 2>&1 || true
log "clamav-freshclam enabled (daily signature updates)"

# First definitions fetch is left to first boot (no network guarantee in
# the installer chroot; freshclam retries on its timer).

# ---------------------------------------------------------------------------
# 3. On-access scanning — OFF by default (see header)
# ---------------------------------------------------------------------------
systemctl disable clamd@scan.service >/dev/null 2>&1 || true
systemctl disable clamonacc.service >/dev/null 2>&1 || true
log "on-access scanning left OFF (Security Space / kaal-antivirus enables it)"

log "antivirus setup complete — try: kaal-antivirus status"
exit 0
