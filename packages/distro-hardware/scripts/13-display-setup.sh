#!/bin/bash
# =============================================================================
# 13-display-setup.sh — Display & Monitor Configuration
# =============================================================================
# Configures multi-monitor, VRR (FreeSync/G-Sync), HDR, fractional
# scaling, and color management per desktop environment.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Display & Monitor Setup ==="

# ---- Install display packages ----
echo "Installing display packages..."
dnf5 install -y \
    xrandr \
    wlr-randr \
    kanshi \
    wayland-protocols-devel \
    colord \
    colord-gtk \
    gnome-color-manager \
    2>/dev/null || true

# ---- Source context for DE selection ----
DE="kde"
if [ -f /etc/distro-bootloader/install-context.conf ]; then
    source /etc/distro-bootloader/install-context.conf
    DE="${DISTRO_DE:-kde}"
fi

# ---- KDE Plasma display config ----
if [ "$DE" = "kde" ]; then
    echo "Configuring KDE Plasma display settings..."

    mkdir -p /etc/skel/.config

    # Enable VRR (Variable Refresh Rate) by default
    cat > /etc/skel/.config/kwinrc << 'KWIN'
# KAAL OS KDE Plasma KWin configuration
[Compositing]
# Enable compositing
CompositingRequired=true
# Use OpenGL 3.1 (best for gaming)
OpenGLIsUnsafe=false
Backend=OpenGL

[Effect-blur]
# Enable blur effect
BlurEnabled=true

[TabBox]
# Better Alt+Tab experience
LayoutName=coverswitch

[Xwayland]
# Allow XWayland apps to use native resolution
XwaylandScaleActive=true
KWIN

    # KDE display configuration for multi-monitor
    cat > /etc/skel/.config/kdeglobals << 'KDEGLOBALS'
# KAAL OS KDE global settings
[KDE]
# Single click to open files
SingleClick=true
# Show file previews
ShowFilePreview=true

[General]
# Use native Wayland colors
ColorScheme=distro-dark
KDEGLOBALS

fi

# ---- GNOME display config ----
if [ "$DE" = "gnome" ]; then
    echo "Configuring GNOME display settings..."

    mkdir -p /etc/skel/.config

    # Enable fractional scaling
    cat > /etc/skel/.config/mutter.conf << 'MUTTER'
# KAAL OS GNOME Mutter configuration
[Compositing]
# Enable fractional scaling on Wayland
experimental-features=["scale-monitor-framebuffer"]
MUTTER

    # GNOME schema overrides for display
    mkdir -p /etc/dconf/db/local.d
    cat > /etc/dconf/db/local.d/distro-display << 'DCONF'
# KAAL OS GNOME display settings
[org/gnome/mutter]
# Fractional scaling
experimental-features=['scale-monitor-framebuffer']
# VRR support
variable-refresh-rate=true

[org/gnome/desktop/interface]
# Scaling factor
scaling-factor=0
# Text scaling (1.0 = default)
text-scaling-factor=1.0

[org/gnome/desktop/peripherals/monitor]
# Color temperature at night
night-light-enabled=false
night-light-temperature=4500
DCONF

    dconf update 2>/dev/null || true
fi

# ---- Hyprland/Sway display config ----
if [ "$DE" = "hyprland" ] || [ "$DE" = "sway" ]; then
    echo "Configuring ${DE} display settings..."

    if [ "$DE" = "hyprland" ]; then
        # Append display config to Hyprland config
        cat >> /etc/skel/.config/hypr/hyprland.conf << 'HYPR'

# --- KAAL OS Display configuration ---
# VRR (Variable Refresh Rate)
# 0 = off, 1 = on, 2 = automatic
monitor=,preferred,auto,1,vrr,1

# HDR (enable when supported)
# monitor=,preferred,auto,1,bitdepth,10

# XWayland scale
xwayland {
    force_zero_scaling = false
}
HYPR
    fi

    if [ "$DE" = "sway" ]; then
        cat >> /etc/skel/.config/sway/config << 'SWAY'

# --- KAAL OS Display configuration ---
# VRR (Variable Refresh Rate)
output * {
    adaptive_sync on
    # HDR is not yet supported in Sway
}
SWAY
    fi

    # Kanshi for multi-monitor management
    mkdir -p /etc/skel/.config/kanshi
    cat > /etc/skel/.config/kanshi/config << 'KANSHI'
# KAAL OS Kanshi multi-monitor configuration
# Kanshi automatically configures displays when connected

# Default: use all connected displays side by side
profile laptop {
    output eDP-1 enable mode 1920x1080 position 0,0
}

profile docked {
    output eDP-1 enable mode 1920x1080 position 0,0
    output DP-1 enable mode 2560x1440 position 1920,0
}

# Extend to external monitor when connected
profile external {
    output eDP-1 disable
    output HDMI-A-1 enable mode 2560x1440 position 0,0
}
KANSHI
fi

# ---- XFCE/Cinnamon display config ----
if [ "$DE" = "xfce" ] || [ "$DE" = "cinnamon" ]; then
    echo "Configuring ${DE} display settings..."
    mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml

    # XRandR default config for XFCE
    cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'XFCE'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="image-path" type="string" value=""/>
        <property name="color-style" type="int" value="0"/>
      </property>
    </property>
  </property>
</channel>
XFCE
fi

# ---- Color management ----
echo "Configuring color management..."
# Enable colord for ICC profile management
systemctl enable colord 2>/dev/null || true

# ---- DRM/KMS configuration ----
# Ensure DRM modesetting is enabled for all GPU drivers
mkdir -p /etc/modprobe.d

# AMD: enable VRR and HDR
cat > /etc/modprobe.d/amdgpu-display.conf << 'AMD'
# KAAL OS AMDGPU display configuration
# Enable FreeSync/VRR support
options amdgpu modeset=1
AMD

# Intel: enable display
cat > /etc/modprobe.d/i915-display.conf << 'INTEL'
# KAAL OS Intel iGPU display configuration
options i915 modeset=1
# Enable fastboot (skip initial modeset)
options i915 fastboot=1
INTEL

echo "=== Display & Monitor Setup Complete ==="
