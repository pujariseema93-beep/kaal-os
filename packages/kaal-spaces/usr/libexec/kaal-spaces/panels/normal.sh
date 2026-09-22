#!/bin/bash
# Normal Space — Panel Layout
# Simple, clean: browser, office, media, file manager pinned

set -euo pipefail

if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.shell favorite-apps \
        "['firefox.desktop', 'org.libreoffice.LibreOffice.desktop', \
        'org.gnome.Nautilus.desktop', 'org.gnome.TextEditor.desktop', \
        'rhythmbox.desktop']" 2>/dev/null || true

    # Simple single workspace for non-technical users
    gsettings set org.gnome.mutter dynamic-workspaces false 2>/dev/null || true
    gsettings set org.gnome.desktop.wm.preferences num-workspaces 1 2>/dev/null || true

    # Larger text for readability
    gsettings set org.gnome.desktop.interface text-scaling-factor 1.1 2>/dev/null || true
fi

# Plasma 6 renamed kwriteconfig5 to kwriteconfig6 — detect the right one
KWRITECONFIG="$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)"

if [[ -n "$KWRITECONFIG" ]]; then
    "$KWRITECONFIG" --file plasmashellrc \
        --group TaskManager --key Pinned \
        "firefox;org.libreoffice.LibreOffice;org.gnome.Nautilus;org.gnome.TextEditor;rhythmbox" 2>/dev/null || true
fi

logger -t kaal-spaces "Normal panel layout applied"
