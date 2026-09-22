#!/bin/bash
# =============================================================================
# 15-usb-setup.sh — USB / Auto-mount / MTP Configuration
# =============================================================================
# Configures automatic mounting of USB drives, SD cards, MTP devices
# (Android phones), PTP cameras, and external displays.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS USB & Auto-mount Setup ==="

# ---- Install USB/storage packages ----
echo "Installing USB and storage packages..."
dnf5 install -y \
    udisks2 \
    gvfs \
    gvfs-mtp \
    gvfs-gphoto2 \
    gvfs-smb \
    gvfs-afc \
    gvfs-goa \
    gvfs-archive \
    gvfs-fuse \
    fuse \
    fuse-libs \
    fuse-exfat \
    exfatprogs \
    ntfs-3g \
    ntfs-3g-system-compression \
    jmtpfs \
    simple-mtpfs \
    libmtp \
    libgphoto2 \
    gphoto2 \
    dosfstools \
    mtools \
    smartmontools \
    udiskie \
    2>/dev/null || true

# ---- Enable udisks2 ----
systemctl enable udisks2 2>/dev/null || true

# ---- Configure auto-mount ----
# udisks2 handles auto-mounting in userspace (no /etc/fstab needed)
# This config ensures consistent mount behavior

mkdir -p /etc/udev/rules.d

# Auto-mount USB drives when connected
cat > /etc/udev/rules.d/99-usb-automount.rules << 'UDEV'
# KAAL OS USB auto-mount udev rules

# Mount USB drives automatically via udisks2
# (udisks2 handles this in userspace — these rules just ensure
#  the devices are accessible and have correct permissions)

# USB storage devices
SUBSYSTEM=="usb", ATTR{bDeviceClass}=="08", MODE="0666"
SUBSYSTEM=="block", SUBSYSTEMS=="usb", MODE="0666"

# SD card readers
SUBSYSTEM=="block", SUBSYSTEMS=="mmc", MODE="0666"

# MTP devices (Android phones in file transfer mode)
SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666"  # Samsung
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666"  # Google
SUBSYSTEM=="usb", ATTR{idVendor}=="22b8", MODE="0666"  # Motorola
SUBSYSTEM=="usb", ATTR{idVendor}=="0bb4", MODE="0666"  # HTC
SUBSYSTEM=="usb", ATTR{idVendor}=="2717", MODE="0666"  # Xiaomi

# PTP cameras (libgphoto2)
SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", MODE="0666"  # Canon
SUBSYSTEM=="usb", ATTR{idVendor}=="04b0", MODE="0666"  # Nikon
SUBSYSTEM=="usb", ATTR{idVendor}=="07b4", MODE="0666"  # Olympus
SUBSYSTEM=="usb", ATTR{idVendor}=="0fca", MODE="0666"  # RIM/BlackBerry

# Apple devices (iPhone/iPad — AFC protocol)
SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", MODE="0666"
UDEV

# ---- udisks2 configuration ----
mkdir -p /etc/udisks2
cat > /etc/udisks2/udisks2.conf << 'UDISKS'
# KAAL OS udisks2 configuration

# Default mount options for various filesystem types
[defaults]
# Common defaults for all filesystems
defaults = {
  # Mount options
  "options" = ["nosuid", "nodev", "nofail", "x-gvfs-show"]
}

# Override per-filesystem
[defaults.filesystem.btrfs]
options = ["nosuid", "nodev", "nofail", "compress=zstd:3", "x-gvfs-show"]

[defaults.filesystem.ntfs]
options = ["nosuid", "nodev", "nofail", "uid=1000", "gid=1000", "dmask=022", "fmask=022", "x-gvfs-show"]

[defaults.filesystem.exfat]
options = ["nosuid", "nodev", "nofail", "uid=1000", "gid=1000", "dmask=022", "fmask=022", "x-gvfs-show"]

[defaults.filesystem.vfat]
options = ["nosuid", "nodev", "nofail", "uid=1000", "gid=1000", "dmask=022", "fmask=022", "shortname=mixed", "x-gvfs-show"]

[defaults.filesystem.ext4]
options = ["nosuid", "nodev", "nofail", "x-gvfs-show"]

[defaults.filesystem.exfat]
options = ["nosuid", "nodev", "nofail", "uid=1000", "gid=1000", "iocharset=utf8", "x-gvfs-show"]
UDISKS

# ---- Configure mount point for removable media ----
# Media mounts at /run/media/<user>/<device-label>
# This is the standard location for all modern Linux distros
mkdir -p /run/media

# ---- FUSE configuration ----
# Ensure FUSE is available for non-root mounting
if [ -f /etc/fuse.conf ]; then
    # Allow user mounting
    sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf 2>/dev/null || true
    # Allow mount_max
    echo "mount_max = 1000" >> /etc/fuse.conf 2>/dev/null || true
else
    cat > /etc/fuse.conf << 'FUSE'
# KAAL OS FUSE configuration
user_allow_other
mount_max = 1000
FUSE
fi

# ---- Polkit rules for auto-mount ----
# Allow users in the "wheel" group to mount and manage disks
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/10-distro-udisks.rules << 'POLKIT'
// KAAL OS Polkit rules for disk management
// Allow users in the wheel group to mount/unmount drives,
// format disks, and manage RAID/LVM without password prompt

polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
        action.id == "org.freedesktop.udisks2.filesystem-mount" ||
        action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
        action.id == "org.freedesktop.udisks2.encrypted-unlock" ||
        action.id == "org.freedesktop.udisks2.encrypted-lock-others" ||
        action.id == "org.freedesktop.udisks2.eject-media" ||
        action.id == "org.freedesktop.udisks2.power-off-drive") {
        if (subject.isInGroup("wheel")) {
            return polkit.Result.YES;
        }
    }
});
POLKIT

# ---- Smart card reader support ----
dnf5 install -y pcsc-lite pcsc-lite-ccid 2>/dev/null || true
systemctl enable pcscd 2>/dev/null || true

# ---- USBGuard (optional security) ----
# USBGuard can restrict which USB devices are allowed
# Disabled by default — users can enable via tweak tool
dnf5 install -y usbguard 2>/dev/null || true
# Don't enable — let the user decide

echo "=== USB & Auto-mount Setup Complete ==="
