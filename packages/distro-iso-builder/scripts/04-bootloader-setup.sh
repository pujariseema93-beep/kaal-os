#!/bin/bash
# =============================================================================
# 04-bootloader-setup.sh — Bootloader Installation (Post-Install)
# =============================================================================
# Installs and configures the bootloader on the target system during
# Calamares post-install. Uses the distro-bootloader-setup script.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Bootloader Installation ==="

# Get bootloader choice (default: grub2)
BOOTLOADER="${DISTRO_BOOTLOADER:-grub2}"
ESP_PATH="/boot/efi"

echo "Selected bootloader: $BOOTLOADER"
echo "ESP path: $ESP_PATH"

# Ensure ESP is mounted
if ! findmnt "$ESP_PATH" >/dev/null 2>&1; then
    echo "WARNING: ESP ($ESP_PATH) not mounted — attempting to mount..."
    mount "$ESP_PATH" 2>/dev/null || true
fi

# Check if our bootloader setup script exists
if [ -x /usr/libexec/distro-bootloader/distro-bootloader-setup ]; then
    echo "Running distro-bootloader-setup..."

    # Detect GPU and build kernel params
    /usr/libexec/distro-bootloader/distro-bootloader-setup --detect-gpu

    # Install the selected bootloader
    /usr/libexec/distro-bootloader/distro-bootloader-setup --install "$BOOTLOADER" --esp "$ESP_PATH"

    # Regenerate initramfs
    /usr/libexec/distro-bootloader/distro-bootloader-setup --regenerate
else
    echo "distro-bootloader-setup not found — using Fedora defaults..."

    # Fall back to standard Fedora bootloader setup
    if [ "$BOOTLOADER" = "systemd-boot" ]; then
        echo "Installing systemd-boot..."
        bootctl install --esp-path="$ESP_PATH" 2>/dev/null || true
    else
        echo "Installing GRUB2..."
        if [ -d /sys/firmware/efi ]; then
            grub2-install --target=x86_64-efi --efi-directory="$ESP_PATH" \
                --bootloader-id="KAAL OS" --recheck 2>/dev/null || true
        else
            ROOT_DISK=$(findmnt -n -o PKNAME "$(findmnt -n -o SOURCE /)")
            grub2-install "$ROOT_DISK" --recheck 2>/dev/null || true
        fi

        # Make GRUB scripts executable
        chmod +x /etc/grub.d/0*-distro* /etc/grub.d/2*-distro* 2>/dev/null || true

        # Generate GRUB config
        if [ -d /sys/firmware/efi ]; then
            grub2-mkconfig -o "$ESP_PATH/EFI/distro/grub.cfg" 2>/dev/null || true
        else
            grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
        fi
    fi

    # Regenerate initramfs
    echo "Regenerating initramfs..."
    for kernel_dir in /lib/modules/*/; do
        kver=$(basename "$kernel_dir")
        dracut --force --kver "$kver" 2>/dev/null || true
    done
fi

# Enable bootloader-related services
systemctl enable kaal-update-check.service 2>/dev/null || true
systemctl enable kaal-update-check.timer 2>/dev/null || true
systemctl enable distro-first-boot.service 2>/dev/null || true

echo "=== Bootloader Installation Complete ==="
