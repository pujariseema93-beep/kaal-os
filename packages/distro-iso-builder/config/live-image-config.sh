#!/bin/bash
# =============================================================================
# live-image-config.sh — Live Image Customization
# =============================================================================
# This script configures the live image environment. It's called by the
# kickstart %post section to set up:
#   - Live user autologin
#   - Display manager for live session
#   - Default DE for live session
#   - Plymouth splash (placeholder)
#   - First-boot service
#   - Network configuration
# =============================================================================

# ---- Live user configuration ----
# The live user (liveuser) gets autologin to try the distro without
# creating an account. This only applies to the live image, not the
# installed system.

LIVE_USER="liveuser"
LIVE_USER_HOME="/home/${LIVE_USER}"

# ---- Create live user skeleton ----
mkdir -p "$LIVE_USER_HOME/.config"
mkdir -p "$LIVE_USER_HOME/Desktop"
mkdir -p "$LIVE_USER_HOME/Downloads"
mkdir -p "$LIVE_USER_HOME/Documents"
mkdir -p "$LIVE_USER_HOME/Pictures"
mkdir -p "$LIVE_USER_HOME/.local/share"

# ---- Set up autologin for SDDM (KDE) ----
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/live-autologin.conf << SDDMEOF
[Autologin]
User=${LIVE_USER}
Session=plasma
SDDMEOF

# ---- Set up autologin for GDM (GNOME) as fallback ----
if [ -f /etc/gdm/custom.conf ]; then
    sed -i 's/AutomaticLoginEnable=false/AutomaticLoginEnable=true/' /etc/gdm/custom.conf
    sed -i 's/AutomaticLogin=/AutomaticLogin='"${LIVE_USER}"'/' /etc/gdm/custom.conf
fi

# ---- Set up autologin for LightDM (XFCE/Cinnamon) ----
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/live-autologin.conf << LIGHTEOF
[Seat:*]
autologin-user=${LIVE_USER}
autologin-user-timeout=0
LIGHTEOF

# ---- Create live user's desktop shortcuts ----
# Add an "Install KAAL OS" icon to the desktop
cat > "$LIVE_USER_HOME/Desktop/install-distro.desktop" << DESKTOPEOF
[Desktop Entry]
Name=Install KAAL OS
Comment=Install KAAL OS to your hard drive
Exec=calamares
Icon=calamares
Terminal=false
Type=Application
Categories=System;
DESKTOPEOF

chmod +x "$LIVE_USER_HOME/Desktop/install-distro.desktop"

# Add a "Read Me" file
cat > "$LIVE_USER_HOME/Desktop/README.txt" << READMEEOF
Welcome to KAAL OS Live!

This is a live environment — nothing is installed yet. Your changes
will be lost when you reboot.

To install KAAL OS permanently:
  1. Double-click "Install KAAL OS" on the desktop
  2. Follow the installer steps
  3. Choose your desktop environment and software profile
  4. Reboot into your new system

To try different desktop environments:
  - Log out of the current session
  - Select a different DE at the login screen

Enjoy!
READMEEOF

# ---- Set live user password to empty (autologin) ----
passwd -d "$LIVE_USER" 2>/dev/null || true

# ---- Create welcome app launcher ----
mkdir -p /usr/share/applications
cat > /usr/share/applications/distro-welcome.desktop << WELCOMEEOF
[Desktop Entry]
Name=KAAL OS Welcome
Comment=Welcome to KAAL OS
Exec=/usr/libexec/distro-bootloader/distro-welcome
Icon=distro-logo
Terminal=false
Type=Application
Categories=System;
StartupNotify=true
WELCOMEEOF

# ---- Configure NetworkManager for live image ----
cat > /etc/NetworkManager/conf.d/live.conf << NMEOF
# KAAL OS Live NetworkManager config
[main]
# Enable auto-connect for any network
no-auto-default=*
NMEOF

# ---- Set default Plymouth theme (placeholder) ----
# When the theme is designed, it will be set here:
# plymouth-set-default-theme distro -R
# For now, use the default Fedora theme
plymouth-set-default-theme spinner -R 2>/dev/null || true

# ---- Set up zram for live image ----
cat > /etc/systemd/zram-generator.conf << ZRAMEOF
# KAAL OS Live zram config
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
ZRAMEOF

# ---- Configure DNF for live image (no updates) ----
cat > /etc/dnf/dnf.conf << 'DNFLIVEEOF'
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=False
skip_if_unavailable=True
# Disable fastestmirror for live (one less thing to configure)
fastestmirror=False
# Don't download metadata in background
metadata_timer_sync=False
DNFLIVEEOF

# ---- Enable services for live image ----
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable bluetooth 2>/dev/null || true
systemctl enable sddm 2>/dev/null || true
systemctl enable pipewire 2>/dev/null || true
systemctl enable wireplumber 2>/dev/null || true
systemctl enable kaal-update-check.timer 2>/dev/null || true

# ---- Disable services not needed on live image ----
systemctl disable smartd 2>/dev/null || true
systemctl disable distro-first-boot.service 2>/dev/null || true  # Only on installed system

echo "Live image customization complete."
