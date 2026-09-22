#!/usr/bin/env bash
# =============================================================================
# 21-vpn-setup.sh — KAAL OS VPN integration
# =============================================================================
# Runs in the Calamares chroot. Ships the open protocol stack so every
# provider works out of the box WITHOUT any third-party repo baked into
# the ISO:
#
#   - WireGuard (kernel-native) + wg/wg-quick tools
#   - OpenVPN + NetworkManager plugin
#   - openconnect (Cisco/AnyConnect/Pulse-compatible) + NM plugin
#
# Provider apps (Proton VPN etc.) are opt-in AFTER install via:
#   kaal-vpn install-proton          # official Proton repo + GUI app
#   kaal-vpn install-proton --cli    # official Proton repo + CLI
#   kaal-vpn import <config>         # WireGuard/OpenVPN profile files
#
# Rationale: a distro image should not carry third-party signing keys
# it cannot revoke on the user's behalf. The protocols are open and
# preinstalled; the trust decision stays with the user.
# =============================================================================

set -euo pipefail

log() { echo "[kaal-security] $*"; }

# ---------------------------------------------------------------------------
# 1. NetworkManager plugins load automatically — nothing to enable, but
#    make sure the VPN connection dir exists with sane permissions.
# ---------------------------------------------------------------------------
if [ -d /etc/NetworkManager ]; then
    install -d -m 0700 /etc/NetworkManager/system-connections
    log "NetworkManager VPN plugin stack ready (wireguard/openvpn/openconnect)"
fi

# ---------------------------------------------------------------------------
# 2. Sanity: warn (not fail) if an expected piece is missing so a package
#    rename in a future Fedora is visible in the install log.
# ---------------------------------------------------------------------------
for tool in wg openvpn openconnect; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[kaal-security] WARNING: '$tool' not found — check package names" >&2
    fi
done

log "VPN setup complete — try: kaal-vpn status"
exit 0
