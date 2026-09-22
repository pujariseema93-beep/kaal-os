#!/bin/bash
# =============================================================================
# 10-bluetooth-setup.sh — Bluetooth Configuration
# =============================================================================
# Configures Bluetooth service, audio pairing via PipeWire, Blueman,
# and codec selection. Ensures Bluetooth headphones/speakers work
# out of the box with high-quality audio.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Bluetooth Setup ==="

# ---- Install Bluetooth packages ----
echo "Installing Bluetooth packages..."
dnf5 install -y \
    bluez \
    bluez-libs \
    bluez-tools \
    blueman \
    bluez-obexd \
    bluez-cups \
    pipewire-libs \
    pulseaudio-libs \
    2>/dev/null || true

# ---- Enable Bluetooth service ----
echo "Enabling Bluetooth service..."
systemctl enable bluetooth 2>/dev/null || true
systemctl enable bluetooth-obex 2>/dev/null || true

# ---- Configure Bluetooth daemon ----
mkdir -p /etc/bluetooth

cat > /etc/bluetooth/main.conf << 'BTCONF'
# KAAL OS Bluetooth Configuration

[General]
# Auto-enable Bluetooth on boot
AutoEnable=true

# Device name shown to other Bluetooth devices
Name = KAAL OS

# Device class (Computer/Desktop)
Class = 0x000100

# Discoverable timeout (0 = always discoverable when enabled)
DiscoverableTimeout = 0

# Pairing timeout in seconds
PairingTimeout = 120

# Default adapter
# ControllerMode = dual

# Privacy: use LE address resolution
Privacy = on

#---- LE Auto Connection ----
[Le]
AutoEnable=true
BTCONF

# ---- Bluetooth audio (PipeWire integration) ----
# PipeWire handles Bluetooth audio via the WirePlumber session manager
# Ensure the correct codecs are available
echo "Configuring Bluetooth audio..."

# Install LDAC, aptX, AAC codec support (via Fedora's PipeWire + fdk-aac)
dnf5 install -y \
    pipewire-libs \
    pipewire-codec-bluetooth \
    libldac \
    libfreeaptx \
    fdk-aac \
    2>/dev/null || true

# Configure WirePlumber for Bluetooth audio
mkdir -p /etc/wireplumber

# Set default Bluetooth codec priority (LDAC > aptX > AAC > SBC)
cat > /etc/wireplumber/50-bluetooth-config.conf << 'WPBT'
# KAAL OS WirePlumber Bluetooth Audio Configuration
#
# Codec priority (highest first):
#   LDAC (hi-res, Sony)     — 990kbps, best quality
#   aptX HD (hi-res, Qualcomm) — 576kbps
#   aptX (Qualcomm)         — 352kbps
#   AAC (Apple)             — 256kbps
#   SBC (standard)          — 328kbps, universal

wireplumber.settings = {
  bluetooth.autoswitch-to-headset-profile = true
  bluetooth.use-persistent-storage = true
  bluetooth.enable-sbc-xq = true
}

monitor.bluetooth.properties = {
  # Preferred codec list (in priority order)
  "bluez5.enable-sbc" = true
  "bluez5.enable-msbc" = true          # Wideband speech for calls
  "bluez5.enable-aac" = true
  "bluez5.enable-aptx" = true
  "bluez5.enable-aptx-hd" = true
  "bluez5.enable-ldac" = true
  "bluez5.enable-faststream" = true    # Low-latency mode for gaming
}
WPBT

# ---- Bluetooth input devices (keyboards, mice, controllers) ----
# Ensure HID over Bluetooth works
echo "Configuring Bluetooth input devices..."
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/bluetooth.conf << 'MOD'
# KAAL OS Bluetooth module configuration
# Enable HID proxy for keyboard/mouse at boot (before pairing)
options bluetooth enable_hs=true enable_le=true
MOD

# ---- udev rules for Bluetooth ----
mkdir -p /etc/udev/rules.d
cat > /etc/udev/rules.d/99-bluetooth.rules << 'UDEV'
# KAAL OS Bluetooth udev rules
# Allow Bluetooth USB dongles to be auto-detected
ACTION=="add", SUBSYSTEM=="bluetooth", RUN+="/usr/bin/systemctl --no-block restart bluetooth"
# Allow rfkill to unblock Bluetooth on boot
ACTION=="add", SUBSYSTEM=="rfkill", RUN+="/usr/sbin/rfkill unblock bluetooth"
UDEV

# ---- Blueman configuration (for XFCE/Cinnamon) ----
# Blueman is the Bluetooth manager for non-KDE/non-GNOME DEs
mkdir -p /etc/xdg/blueman
cat > /etc/xdg/blueman/blueman-applet.conf << 'BLU'
# KAAL OS Blueman configuration
[Plugins]
ManagerPriority = [Manager, RecentConns, Headset, Menu, PowerManager, StatusIcon, NMDUNSupport, PPPSupport, NMPANSupport, GameController, AutoConnect, KillSwitch, DBusPlugin, DhcpClient, NetUsage, SerialManager]
StatusIcon = true
AutoConnect = true

[Plugins.StatusIcon]
# Show Bluetooth icon in system tray
visible = true

[Plugins.AutoConnect]
# Auto-reconnect to last device on boot
recent_connections = 3
BLU

echo "=== Bluetooth Setup Complete ==="
