#!/bin/bash
# =============================================================================
# 07-finalize.sh — Final Post-Install Steps (Post-Install)
# =============================================================================
# Last script to run during Calamares post-install. Cleans up, creates
# final configuration, and prepares the system for first boot.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Final Post-Install Steps ==="

# ---- Remove live user (only on installed system, not live) ----
if id liveuser >/dev/null 2>&1; then
    echo "Removing live user..."
    userdel -r liveuser 2>/dev/null || true
fi

# ---- Create default user skeleton files ----
mkdir -p /etc/skel/.config
mkdir -p /etc/skel/.local/share

# ---- Create distro info file ----
cat > /etc/distro-installed << 'INSTEOF'
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
INSTALL_PROFILE=${DISTRO_PROFILE:-gaming}
INSTALL_DE=${DISTRO_DE:-kde}
INSTALL_BOOTLOADER=${DISTRO_BOOTLOADER:-grub2}
INSTEOF

# ---- Enable first-boot service ----
systemctl enable distro-first-boot.service 2>/dev/null || true

# ---- Clean up DNF cache ----
dnf5 clean all 2>/dev/null || true
rm -rf /var/cache/dnf/* 2>/dev/null || true

# ---- Set up journal size limit ----
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/distro.conf << 'JEOF'
# KAAL OS Journal Configuration
[Journal]
SystemMaxUse=500M
SystemMaxFileSize=50M
MaxRetentionSec=2week
JEOF

# ---- Create update preferences ----
if [ ! -f /etc/distro-bootloader/update-preferences.conf ]; then
    mkdir -p /etc/distro-bootloader
    cat > /etc/distro-bootloader/update-preferences.conf << 'PREFEOF'
MODE=manual
CHECK_INTERVAL_HOURS=4
DOWNLOAD_METERED=false
AUTO_SNAPSHOT=true
MAX_SPEED_KBPS=0
FIRMWARE_UPDATES=true
FLATPAK_UPDATES=true
PREFEOF
fi

# ---- Create distro directories ----
mkdir -p /var/log/distro
mkdir -p /usr/share/distro/profiles

# ---- Final GRUB regeneration ----
echo "Final GRUB regeneration..."
chmod +x /etc/grub.d/0*-distro* /etc/grub.d/2*-distro* 2>/dev/null || true
if [ -d /sys/firmware/efi ]; then
    grub2-mkconfig -o /boot/efi/EFI/distro/grub.cfg 2>/dev/null || true
else
    grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
fi

# ---- Final initramfs regeneration ----
echo "Final initramfs regeneration..."
for kernel_dir in /lib/modules/*/; do
    kver=$(basename "$kernel_dir")
    dracut --force --kver "$kver" 2>/dev/null || true
done

# ---- Mark installation as complete ----
echo "Installation completed at $(date '+%Y-%m-%d %H:%M:%S')" > /etc/distro-bootloader/install-complete

echo "=== Final Post-Install Steps Complete ==="
echo ""
echo "KAAL OS is ready for first boot."
echo "The first-boot service will:"
echo "  1. Detect and configure GPU drivers"
echo "  2. Regenerate initramfs with correct drivers"
echo "  3. Enable the selected display manager"
echo "  4. Configure zram swap"
echo "  5. Set up Btrfs snapshots (if available)"
echo "  6. Enable auto-update on boot"
echo ""
echo "Reboot to start using KAAL OS!"
