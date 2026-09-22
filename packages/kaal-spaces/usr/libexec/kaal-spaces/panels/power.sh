#!/bin/bash
# Power User Space — Panel Layout
# System monitors, config tools, terminal pinned

set -euo pipefail

if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.shell favorite-apps \
        "['org.gnome.Terminal.desktop', 'htop.desktop', 'btop.desktop', \
        'org.gnome.SystemMonitor.desktop', 'org.gnome.DiskUtility.desktop', \
        'gparted.desktop', 'dnfdragora.desktop', 'org.gnome.tweaks.desktop']" 2>/dev/null || true

    # Show all extensions
    gsettings set org.gnome.shell disable-user-extensions false 2>/dev/null || true
fi

# Plasma 6 renamed kwriteconfig5 to kwriteconfig6 — detect the right one
KWRITECONFIG="$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)"

if [[ -n "$KWRITECONFIG" ]]; then
    "$KWRITECONFIG" --file plasmashellrc \
        --group TaskManager --key Pinned \
        "org.gnome.Terminal;htop;btop;org.gnome.SystemMonitor;org.gnome.DiskUtility;gparted;dnfdragora;org.gnome.tweaks" 2>/dev/null || true
fi

logger -t kaal-spaces "Power User panel layout applied"
