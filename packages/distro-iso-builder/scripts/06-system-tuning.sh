#!/bin/bash
# =============================================================================
# 06-system-tuning.sh — System Performance Tuning (Post-Install)
# =============================================================================
# Applies gaming and performance optimizations to the installed system.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS System Performance Tuning ==="

# ---- CPU Governor ----
# Set performance governor on AC power, powersave on battery
mkdir -p /etc/distro-bootloader

cat > /etc/distro-bootloader/cpu-governor.conf << 'CPUEOF'
# KAAL OS CPU Governor Configuration
# Applied by power-profiles-daemon or kaal-tweak-tool

# AC power governor
AC_GOVERNOR=performance

# Battery governor
BATTERY_GOVERNOR=powersave

# Enable auto-switching (true/false)
AUTO_SWITCH=true
CPUEOF

# ---- I/O Scheduler ----
# Set BFQ for SATA/SAS, none for NVMe (kernel default is good)
cat > /etc/udev/rules.d/60-distro-io-scheduler.rules << 'IOEOF'
# KAAL OS I/O Scheduler Rules
# BFQ for traditional drives (best for desktop responsiveness)
ACTION=="add|change", KERNEL=="sd[a-z]|cciss!c[0-9]d[0-9]", ATTR{queue/scheduler}="bfq"

# none for NVMe (kernel default is optimal)
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"

# bfq for eMMC and SD cards
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/scheduler}="bfq"
IOEOF

# ---- Swap / zram ----
# Configure zram (already set up by Fedora, but ensure our config)
if [ ! -f /etc/systemd/zram-generator.conf ] || ! grep -q 'distro' /etc/systemd/zram-generator.conf 2>/dev/null; then
    cat > /etc/systemd/zram-generator.conf << 'ZRAMEOF'
# KAAL OS zram configuration
# zram provides compressed swap in RAM — faster than disk swap
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
ZRAMEOF
fi

# ---- Sysctl tuning for gaming ----
cat > /etc/sysctl.d/99-distro-gaming.conf << 'SYSCTL'
# KAAL OS Gaming & Performance Sysctl Tuning

# Increase max file watches (for game mods, file managers)
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

# Reduce swappiness (prefer RAM over swap)
vm.swappiness = 10

# Increase virtual memory max map count (needed for some games)
vm.max_map_count = 2147483647

# Improve network latency
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 4096

# TCP tuning for gaming
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
SYSCTL

# ---- Disable unnecessary services for performance ----
SERVICES_TO_DISABLE=(
    "avahi-daemon"      # mDNS — most users don't need it
    "cups"              # Printing — enable only if printer connected
    "smartd"            # Disk monitoring — can cause latency
)

for svc in "${SERVICES_TO_DISABLE[@]}"; do
    echo "Disabling: $svc"
    systemctl disable "$svc" 2>/dev/null || true
done

# ---- Enable useful services ----
SERVICES_TO_ENABLE=(
    "bluetooth"
    "NetworkManager"
    "pipewire"
    "wireplumber"
    "power-profiles-daemon"
)

for svc in "${SERVICES_TO_ENABLE[@]}"; do
    echo "Enabling: $svc"
    systemctl enable "$svc" 2>/dev/null || true
done

# ---- Set up limits.conf for gaming ----
cat > /etc/security/limits.d/99-distro-gaming.conf << 'LIMITS'
# KAAL OS Gaming Limits Configuration
# Increase priority limits for the games group

# Realtime priority for games
@wheel   soft   priority   5
@wheel   hard   priority   10

# Max locked memory (for games that pin memory)
@wheel   soft   memlock    unlimited
@wheel   hard   memlock    unlimited
LIMITS

# ---- Set up Btrfs snapshot timers ----
if command -v snapper >/dev/null 2>&1; then
    echo "Configuring snapper timers..."
    systemctl enable snapper-timeline.timer 2>/dev/null || true
    systemctl enable snapper-cleanup.timer 2>/dev/null || true

    # Configure snapper defaults
    if [ ! -f /etc/snapper/configs/root ]; then
        snapper -c root create-config -f btrfs / 2>/dev/null || true
    fi
fi

echo "=== System Performance Tuning Complete ==="
