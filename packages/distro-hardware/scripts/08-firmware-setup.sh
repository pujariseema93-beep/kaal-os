#!/bin/bash
# =============================================================================
# 08-firmware-setup.sh — Hardware Firmware Installation
# =============================================================================
# Detects hardware (WiFi, Bluetooth, webcam, sensors) and installs the
# correct firmware packages. Without these, WiFi cards won't connect,
# Bluetooth won't pair, and some webcams won't initialize.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Hardware Firmware Setup ==="

# ---- Install fwupd (firmware update daemon) ----
echo "Installing fwupd..."
dnf5 install -y fwupd fwupd-efi 2>/dev/null || true
systemctl enable fwupd 2>/dev/null || true

# ---- WiFi firmware ----
echo "Detecting WiFi adapter..."
WIFI_CHIP=$(lspci -nn 2>/dev/null | grep -i 'network controller\|wireless' || true)
USB_WIFI=$(lsusb 2>/dev/null | grep -i 'wireless\|wifi\|802\.11' || true)

echo "  PCI WiFi: ${WIFI_CHIP:-none detected}"
echo "  USB WiFi: ${USB_WIFI:-none detected}"

# Install firmware for all common WiFi chipsets
WIFI_FIRMWARE_PKGS=(
    # Intel WiFi (most common in laptops)
    iwlax2-firmware        # Intel BE200 (WiFi 7)
    iwl7265-firmware       # Intel 7265/3165/8260/4165
    iwl6050-firmware       # Intel 6050/6005/6030/6000
    iwl5000-firmware       # Intel 5100/5300/5350/5150/5000
    iwl1000-firmware       # Intel 1000/100/105/135
    iwl2000-firmware       # Intel 2000/2030/105/135
    iwl3945-firmware       # Intel 3945 (old)
    iwl4965-firmware       # Intel 4965 (old)

    # Realtek
    rtl-sdr                # RTL-SDR (also provides some WiFi firmware)

    # Broadcom (requires RPM Fusion nonfree)
    # broadcom-bt-firmware  # Bluetooth firmware for Broadcom

    # MediaTek / Ralink
    # These are in linux-firmware, no separate package needed
)

echo "Installing WiFi firmware packages..."
for pkg in "${WIFI_FIRMWARE_PKGS[@]}"; do
    dnf5 install -y "$pkg" 2>/dev/null || echo "  SKIP: $pkg (not available)"
done

# Install the main linux-firmware package (covers most Realtek, MediaTek, Atheros)
dnf5 install -y linux-firmware linux-firmware-ivtv 2>/dev/null || true

# ---- Bluetooth firmware ----
echo "Detecting Bluetooth adapter..."
BT_DETECTED=$(lsusb 2>/dev/null | grep -i bluetooth || true)
BT_PCI=$(lspci -nn 2>/dev/null | grep -i bluetooth || true)

echo "  USB Bluetooth: ${BT_DETECTED:-none detected}"
echo "  PCI Bluetooth: ${BT_PCI:-none detected}"

# Install Broadcom Bluetooth firmware (common in MacBooks)
dnf5 install -y broadcom-bt-firmware 2>/dev/null || echo "  SKIP: broadcom-bt-firmware (RPM Fusion nonfree)"

# ---- Webcam firmware ----
echo "Detecting webcam..."
WEBCAM=$(lsusb 2>/dev/null | grep -iE 'camera|webcam|video|uvc' || true)
echo "  Webcam: ${WEBCAM:-none detected}"

# Most webcams work with the UVC kernel driver + uvcvideo
# Some specific cameras need firmware:
#   - Logitech C920 etc: no firmware needed (UVC)
#   - Lenovo ThinkPad cameras: no firmware needed
#   - Some older cameras: may need specific firmware

# ---- Sensor firmware ----
# Install lm_sensors for temperature/fan monitoring
echo "Installing sensor support..."
dnf5 install -y lm_sensors sensord 2>/dev/null || true

# Run sensors-detect non-interactively
if command -v sensors-detect >/dev/null 2>&1; then
    echo "Running sensor detection..."
    sensors-detect --auto 2>/dev/null || true
fi

# ---- Touchpad / Trackpad ----
# Synaptics and libinput are already in the base, but ensure:
echo "Installing input device drivers..."
dnf5 install -y libinput xf86-input-libinput 2>/dev/null || true

# ---- SD card reader firmware ----
# Most SD card readers use the standard USB storage or mmc drivers
# No extra firmware needed, but ensure the module is available:
dnf5 install -y mmc-utils 2>/dev/null || true

# ---- Run fwupd to populate firmware device list ----
if command -v fwupdmgr >/dev/null 2>&1; then
    echo "Populating firmware device list..."
    fwupdmgr refresh --quiet 2>/dev/null || true
    fwupdmgr get-devices --quiet 2>/dev/null | head -50 || true
fi

echo "=== Hardware Firmware Setup Complete ==="
