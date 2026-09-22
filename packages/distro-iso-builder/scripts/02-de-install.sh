#!/bin/bash
# =============================================================================
# 02-de-install.sh — Desktop Environment Installation (Post-Install)
# =============================================================================
# Installs the user-selected desktop environment during Calamares post-install.
# The DE choice is passed via the KAAL OS_DE environment variable
# (set by the Calamares users module or a custom module).
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Desktop Environment Installation ==="

# Get DE choice (default to kde if not set)
DE_CHOICE="${DISTRO_DE:-kde}"

echo "Selected desktop environment: $DE_CHOICE"

case "$DE_CHOICE" in
    kde|plasma)
        echo "Installing KDE Plasma 6..."
        dnf5 group install -y kde-desktop 2>/dev/null || dnf5 install -y @kde-desktop 2>/dev/null || true
        systemctl enable sddm 2>/dev/null || true
        # Set SDDM as the display manager
        echo "sddm" > /etc/distro-bootloader/display-manager
        ;;

    gnome)
        echo "Installing GNOME 47..."
        dnf5 group install -y gnome-desktop 2>/dev/null || dnf5 install -y @gnome-desktop 2>/dev/null || true
        systemctl enable gdm 2>/dev/null || true
        echo "gdm" > /etc/distro-bootloader/display-manager
        ;;

    hyprland)
        echo "Installing Hyprland..."
        dnf5 install -y hyprland waybar wofi foot wl-clipboard swaylock swayidle dunst polkit-gnome 2>/dev/null || true
        # Create default Hyprland config
        mkdir -p /etc/skel/.config/hypr
        cat > /etc/skel/.config/hypr/hyprland.conf << 'HYPRCONF'
# KAAL OS default Hyprland config
# Full customization available via kaal-theme-manager

# Monitor
monitor=,preferred,auto,1

# Programs
$terminal = foot
$menu = wofi --show drun

# Autostart
exec-once = waybar

# Mod key
$mainMod = SUPER

# Keybindings
bind = $mainMod, Return, exec, $terminal
bind = $mainMod, D, exec, $menu
bind = $mainMod SHIFT, Q, killactive,
bind = $mainMod SHIFT, E, exit,
HYPRCONF
        # Use SDDM for Hyprland login
        dnf5 install -y sddm 2>/dev/null || true
        systemctl enable sddm 2>/dev/null || true
        echo "sddm" > /etc/distro-bootloader/display-manager
        ;;

    sway)
        echo "Installing Sway..."
        dnf5 install -y sway waybar wofi foot wl-clipboard swaylock swayidle 2>/dev/null || true
        mkdir -p /etc/skel/.config/sway
        cat > /etc/skel/.config/sway/config << 'SWAYCONF'
# KAAL OS default Sway config
# Full customization available via kaal-theme-manager

set $terminal foot
set $menu wofi --show drun

font pango:JetBrains Mono 10

bar {
    status_command while waybar; do :; done
}

# Mod key
set $mod Mod4

# Keybindings
bindsym $mod+Return exec $terminal
bindsym $mod+d exec $menu
bindsym $mod+Shift+q kill
bindsym $mod+Shift+e exit
SWAYCONF
        dnf5 install -y sddm 2>/dev/null || true
        systemctl enable sddm 2>/dev/null || true
        echo "sddm" > /etc/distro-bootloader/display-manager
        ;;

    xfce)
        echo "Installing XFCE..."
        dnf5 group install -y xfce-desktop 2>/dev/null || dnf5 install -y @xfce-desktop 2>/dev/null || true
        dnf5 install -y lightdm 2>/dev/null || true
        systemctl enable lightdm 2>/dev/null || true
        echo "lightdm" > /etc/distro-bootloader/display-manager
        ;;

    cinnamon)
        echo "Installing Cinnamon..."
        dnf5 group install -y cinnamon-desktop 2>/dev/null || dnf5 install -y @cinnamon-desktop 2>/dev/null || true
        dnf5 install -y lightdm 2>/dev/null || true
        systemctl enable lightdm 2>/dev/null || true
        echo "lightdm" > /etc/distro-bootloader/display-manager
        ;;

    *)
        echo "Unknown DE: $DE_CHOICE — defaulting to KDE Plasma"
        dnf5 group install -y kde-desktop 2>/dev/null || true
        systemctl enable sddm 2>/dev/null || true
        echo "sddm" > /etc/distro-bootloader/display-manager
        ;;
esac

echo "Display manager set to: $(cat /etc/distro-bootloader/display-manager 2>/dev/null || echo 'unknown')"
echo "=== Desktop Environment Installation Complete ==="
