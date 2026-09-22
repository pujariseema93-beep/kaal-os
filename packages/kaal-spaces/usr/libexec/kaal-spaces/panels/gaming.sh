#!/bin/bash
# Gaming Space — Panel Layout
# Game launcher focused: Steam/Lutris/Bottles pinned, performance stats visible

set -euo pipefail

# GNOME: configure dash-to-dock or top bar
if command -v gsettings &>/dev/null; then
    # Pin gaming apps to dash
    gsettings set org.gnome.shell favorite-apps \
        "['steam.desktop', 'lutris.desktop', 'bottles.desktop', \
        'heroicgameslauncher.desktop', 'mangohud.desktop']" 2>/dev/null || true

    # Show battery percentage for laptops
    gsettings set org.gnome.desktop.interface show-battery-percentage true 2>/dev/null || true

    # Disable workspace auto-switch (gaming uses fullscreen)
    gsettings set org.gnome.mutter dynamic-workspaces false 2>/dev/null || true
fi

# KDE Plasma: configure panel
# Plasma 6 renamed kwriteconfig5 to kwriteconfig6 — detect the right one
KWRITECONFIG="$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)"

if [[ -n "$KWRITECONFIG" ]]; then
    # Pin gaming apps to task manager
    "$KWRITECONFIG" --file plasmashellrc \
        --group TaskManager --key Pinned \
        "steam;lutris;bottles;heroicgameslauncher" 2>/dev/null || true
fi

# Hyprland/Sway: configure via config overlay
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    # Pin gaming windows to workspace 1
    hyprctl keyword windowrule "workspace 1 silent, class:^(steam|Steam)$" 2>/dev/null || true
fi

logger -t kaal-spaces "Gaming panel layout applied"
