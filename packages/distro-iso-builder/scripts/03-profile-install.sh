#!/bin/bash
# =============================================================================
# 03-profile-install.sh — Software Profile Installation (Post-Install)
# =============================================================================
# Installs the user-selected software profile during Calamares post-install.
# The profile choice is passed via the DISTRO_PROFILE environment variable.
#
# Profiles:
#   gaming      — Steam, Proton, emulators, performance tools
#   developer   — IDEs, languages, containers, terminal tools
#   power-user  — Tiling WMs, system tools, customization
#   daily       — Browsers, office, media, creative apps
#   minimal     — Base system + DE only
#   custom      — Skip profile, user will install manually
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Software Profile Installation ==="

PROFILE="${DISTRO_PROFILE:-gaming}"
PROFILE_DIR="/usr/share/distro/profiles"

echo "Selected profile: $PROFILE"

if [ "$PROFILE" = "custom" ] || [ "$PROFILE" = "minimal" ]; then
    echo "Skipping profile installation ($PROFILE)"
    if [ "$PROFILE" = "minimal" ] && [ -f "$PROFILE_DIR/minimal.list" ]; then
        echo "Installing minimal packages..."
        dnf5 install -y $(grep -v '^#' "$PROFILE_DIR/minimal.list" | grep -v '^$' | tr '\n' ' ') 2>/dev/null || true
    fi
    echo "=== Profile Installation Complete ==="
    exit 0
fi

# Check if profile list exists
LIST_FILE="$PROFILE_DIR/${PROFILE}.list"
if [ ! -f "$LIST_FILE" ]; then
    echo "WARNING: Profile list not found: $LIST_FILE"
    echo "Available profiles: $(find "$PROFILE_DIR" -name "*.list" -exec basename {} .list \; 2>/dev/null | tr '\n' ' ')"
    echo "Falling back to gaming profile"
    PROFILE="gaming"
    LIST_FILE="$PROFILE_DIR/${PROFILE}.list"
fi

# Install packages from the profile list
echo "Installing packages from $LIST_FILE..."

# Read the package list, skip comments and empty lines
PACKAGES="$(grep -v '^#' "$LIST_FILE" | grep -v '^$' | tr '\n' ' ')"

if [ -n "$PACKAGES" ]; then
    echo "Packages to install: $(echo "$PACKAGES" | wc -w) packages"
    dnf5 install -y $PACKAGES 2>/dev/null || {
        echo "Some packages failed to install, retrying individually..."
        for pkg in $PACKAGES; do
            dnf5 install -y "$pkg" 2>/dev/null || echo "  SKIP: $pkg (not found)"
        done
    }
fi

# ---- Profile-specific post-setup ----
case "$PROFILE" in
    gaming)
        echo "Running gaming profile post-setup..."

        # Install GE-Proton via ProtonUp-Qt
        # (This would be done by the user after first boot, as it requires download)

        # Enable GameMode daemon
        systemctl enable gamemoded 2>/dev/null || true

        # Configure Steam to use Proton
        mkdir -p /etc/skel/.steam

        # Set up MangoHud as default for Steam games
        mkdir -p /etc/skel/.config
        cat > /etc/skel/.config/MangoHud.conf << 'MANGOEOF'
# KAAL OS default MangoHud config
preset=3
MANGOEOF

        echo "Gaming profile setup complete"
        ;;

    developer)
        echo "Running developer profile post-setup..."

        # Enable Docker
        systemctl enable docker 2>/dev/null || true
        systemctl enable podman.socket 2>/dev/null || true

        # Set up Distrobox default image
        mkdir -p /etc/distrobox
        cat > /etc/distrobox/distrobox.conf << 'DBOXEOF'
# KAAL OS Distrobox config
container_manager="podman"
DBOXEOF

        # Enable libvirtd for VMs
        systemctl enable libvirtd 2>/dev/null || true

        echo "Developer profile setup complete"
        ;;

    power-user)
        echo "Running power-user profile post-setup..."

        # Enable thermald (if Intel CPU)
        if grep -q 'Intel' /proc/cpuinfo 2>/dev/null; then
            systemctl enable thermald 2>/dev/null || true
        fi

        # Enable power-profiles-daemon
        systemctl enable power-profiles-daemon 2>/dev/null || true

        echo "Power-user profile setup complete"
        ;;

    daily)
        echo "Running daily profile post-setup..."

        # Enable Bluetooth
        systemctl enable bluetooth 2>/dev/null || true

        # Enable printing
        systemctl enable cups 2>/dev/null || true

        # Enable Syncthing
        systemctl enable syncthing@ 2>/dev/null || true

        echo "Daily profile setup complete"
        ;;
esac

echo "=== Software Profile Installation Complete ==="
