#!/bin/bash
# Development Space — Panel Layout
# IDE and terminal focused: code editors, terminal, git tools pinned

set -euo pipefail

if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.shell favorite-apps \
        "['code.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.gitg.desktop', \
        'dbeaver.desktop', 'org.gnome.SystemMonitor.desktop']" 2>/dev/null || true

    # Enable workspaces for multi-project workflow
    gsettings set org.gnome.mutter dynamic-workspaces true 2>/dev/null || true
    gsettings set org.gnome.desktop.wm.preferences num-workspaces 4 2>/dev/null || true
fi

# Plasma 6 renamed kwriteconfig5 to kwriteconfig6 — detect the right one
KWRITECONFIG="$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)"

if [[ -n "$KWRITECONFIG" ]]; then
    "$KWRITECONFIG" --file plasmashellrc \
        --group TaskManager --key Pinned \
        "code;org.gnome.Terminal;org.gnome.gitg;dbeaver;org.gnome.SystemMonitor" 2>/dev/null || true
fi

logger -t kaal-spaces "Development panel layout applied"
