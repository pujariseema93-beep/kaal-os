#!/bin/bash
# =============================================================================
# config.sh — KAAL OS image customization (runs inside the image root
#              during the kiwi build, before the ISO is packed)
# =============================================================================
# This is the kiwi equivalent of the %post section of distro-live.ks.
# It runs chrooted inside the built image. Keep it POSIX-safe and idempotent.
# =============================================================================

set -euxo pipefail

echo "== KAAL OS: applying image customization =="

# ---- 1. Identity: os-release -----------------------------------------------
cat > /etc/os-release << 'EOF'
NAME="KAAL OS"
ID=kaal
ID_LIKE=fedora
VERSION="0.1.0"
PRETTY_NAME="KAAL OS 0.1.0 (Live)"
ANSI_COLOR="0;36"
HOME_URL="https://github.com/pujariseema93-beep/kaal-os"
EOF

echo "kaal-live" > /etc/hostname

# ---- 2. Live session: SDDM autologin ---------------------------------------
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/kaal-live.conf << 'EOF'
[Autologin]
User=liveuser
Session=plasma
Relogin=true

[Theme]
Current=kaal
EOF

# Ensure the live user exists and is in the right groups (kiwi's <users>
# creates it; wheel membership comes from the image description)
passwd -d liveuser || true

# ---- 3. Services -------------------------------------------------------------
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable sddm 2>/dev/null || true
systemctl set-default graphical.target 2>/dev/null || true

# ---- 4. DNF config: fastestmirror + keep downloads small --------------------
mkdir -p /etc/dnf
cat > /etc/dnf/dnf.conf << 'EOF'
[main]
fastestmirror=True
max_parallel_downloads=10
keepcache=0
EOF

# ---- 5. Cleanup --------------------------------------------------------------
dnf clean all 2>/dev/null || true
rm -rf /var/cache/dnf/* /var/tmp/* /tmp/* 2>/dev/null || true
truncate -s 0 /var/log/*.log 2>/dev/null || true

echo "== KAAL OS: customization complete =="
