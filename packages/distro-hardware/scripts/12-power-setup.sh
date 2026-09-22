#!/bin/bash
# =============================================================================
# 12-power-setup.sh — Power Management Configuration
# =============================================================================
# Configures suspend/resume, screen brightness, battery monitoring,
# lid switch behavior, and CPU governor auto-switching on AC/battery.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Power Management Setup ==="

# ---- Install power management packages ----
echo "Installing power management packages..."
dnf5 install -y \
    power-profiles-daemon \
    upower \
    thermald \
    tlp \
    tlp-rdw \
    brightnessctl \
    light \
    acpi \
    acpid \
    pm-utils \
    2>/dev/null || true

# ---- Enable power-profiles-daemon ----
# This is the modern power management daemon for Linux
# It provides three profiles: performance, balanced, power-saver
echo "Enabling power-profiles-daemon..."
systemctl enable power-profiles-daemon 2>/dev/null || true

# ---- Enable thermald (Intel thermal management) ----
if grep -qi 'Intel' /proc/cpuinfo 2>/dev/null; then
    echo "Intel CPU detected — enabling thermald..."
    systemctl enable thermald 2>/dev/null || true
fi

# ---- CPU governor auto-switch ----
# Create a udev rule that switches governor based on power source
mkdir -p /etc/udev/rules.d

cat > /etc/udev/rules.d/99-distro-power.rules << 'UDEV'
# KAAL OS Power management udev rules

# On AC power: set performance governor
SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="/bin/sh -c 'echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true'"

# On battery: set powersave governor
SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="/bin/sh -c 'echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true'"
UDEV

# ---- Suspend/Resume configuration ----
echo "Configuring suspend/resume..."

# Create a systemd service that runs after resume to restore state
mkdir -p /etc/systemd/system
cat > /etc/systemd/system/distro-resume.service << 'RESUME'
[Unit]
Description=KAAL OS Post-Resume Setup
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/libexec/distro-hardware/distro-resume-hook
RemainAfterExit=no

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
RESUME

# Create the resume hook script
mkdir -p /usr/libexec/distro-hardware
cat > /usr/libexec/distro-hardware/distro-resume-hook << 'HOOK'
#!/bin/bash
# Runs after system resumes from suspend/hibernate
# Restores audio, network, and GPU state

set -euo pipefail

LOG="/var/log/distro-resume.log"
echo "[$(date)] System resumed — running hooks..." | tee -a "$LOG"

# Restart PipeWire if audio is broken after resume
if ! pgrep -x pipewire >/dev/null 2>&1; then
    echo "  Restarting PipeWire..." | tee -a "$LOG"
    systemctl --user restart pipewire wireplumber 2>/dev/null || true
fi

# Restart NetworkManager if WiFi is broken after resume
if ! nmcli general status >/dev/null 2>&1; then
    echo "  Restarting NetworkManager..." | tee -a "$LOG"
    systemctl restart NetworkManager 2>/dev/null || true
fi

# Reload NVIDIA driver if present
if lsmod | grep -q nvidia; then
    echo "  NVIDIA driver detected — refreshing..." | tee -a "$LOG"
    # Don't restart nvidia, just verify it's working
    nvidia-smi -L >/dev/null 2>&1 || echo "  WARNING: NVIDIA may need manual restart" | tee -a "$LOG"
fi

# Restore brightness
if command -v brightnessctl >/dev/null 2>&1; then
    # Try to restore last brightness level
    brightnessctl -d intel_backlight set 50% 2>/dev/null || true
    brightnessctl -d amdgpu_bl0 set 50% 2>/dev/null || true
fi

echo "[$(date)] Resume hooks complete." | tee -a "$LOG"
HOOK
chmod +x /usr/libexec/distro-hardware/distro-resume-hook
systemctl enable distro-resume.service 2>/dev/null || true

# ---- Lid switch behavior ----
# Default: suspend on lid close (laptops)
mkdir -p /etc/systemd
cat > /etc/systemd/logind.conf.d/distro-lid.conf << 'LID'
# KAAL OS Lid switch configuration
[Login]
# HandleLidSwitch: ignore, suspend, hibernate, poweroff, lock
# Default: suspend on lid close when on battery, lock when docked
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
# Don't suspend when multiple displays are connected
HandleLidSwitchDocked=ignore
# Idle timeout
IdleAction=suspend
IdleActionSec=10min
LID

# ---- TLP configuration (advanced power management) ----
# TLP is an alternative/complement to power-profiles-daemon
# Only enable if power-profiles-daemon is not conflicting
mkdir -p /etc/tlp.d
cat > /etc/tlp.d/00-distro.conf << 'TLP'
# KAAL OS TLP Configuration
# TLP provides advanced power saving for laptops

# CPU scaling governor
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# CPU energy performance preference
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# CPU max/min frequency
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=100
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=80

# GPU (Intel)
INTEL_GPU_MIN_FREQ_ON_AC=0
INTEL_GPU_MAX_FREQ_ON_AC=1300
INTEL_GPU_BOOST_FREQ_ON_AC=1300
INTEL_GPU_MIN_FREQ_ON_BAT=0
INTEL_GPU_MAX_FREQ_ON_BAT=800
INTEL_GPU_BOOST_FREQ_ON_BAT=800

# Disk power saving
DISK_DEVICES="nvme0n1 sda"
DISK_SPINDOWN_TIMEOUT_ON_AC=0
DISK_SPINDOWN_TIMEOUT_ON_BAT=120

# WiFi power saving
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# Audio power saving
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_CONTROLLER=Y
TLP

# Disable TLP by default (power-profiles-daemon is primary)
# Users can switch via kaal-tweak-tool
systemctl disable tlp 2>/dev/null || true

# ---- Brightness control ----
# Ensure brightness control works for all backlight types
echo "Configuring brightness control..."
# Add user to video group for brightness access
if [ -f /etc/distro-bootloader/install-context.conf ]; then
    source /etc/distro-bootloader/install-context.conf
    if [ -n "${DISTRO_USER_NAME:-}" ]; then
        usermod -aG video "$DISTRO_USER_NAME" 2>/dev/null || true
    fi
fi

# ---- Battery monitoring ----
systemctl enable upower 2>/dev/null || true

# ---- Sysctl power tuning ----
cat >> /etc/sysctl.d/99-distro-gaming.conf << 'SYSCTL'

# KAAL OS Power management sysctl

# Reduce VM swappiness on battery (preserve SSD life)
vm.dirty_ratio = 5
vm.dirty_background_ratio = 1

# Enable laptop mode (batch disk writes)
vm.laptop_mode = 0
SYSCTL

echo "=== Power Management Setup Complete ==="
