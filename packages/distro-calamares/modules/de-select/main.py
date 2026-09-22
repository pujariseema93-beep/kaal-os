#!/usr/bin/env python3
# =============================================================================
# main.py — Calamares View Module: Desktop Environment Selection
# =============================================================================
# Displays a screen where the user picks their desktop environment.
# The selection is stored in global storage as "distroDE" and written
# to a context file for the post-install scripts.
#
# Place at: /usr/lib/calamares/modules/de-select/main.py
# =============================================================================

import calamares
import os

try:
    from PyQt5.QtWidgets import (
        QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
        QButtonGroup, QRadioButton, QScrollArea, QFrame, QSizePolicy,
    )
    from PyQt5.QtCore import Qt
    from PyQt5.QtGui import QFont
    HAS_PYQT = True
except ImportError:
    HAS_PYQT = False

__pretty_name__ = "Desktop Environment"
_selected_de = None
_config = None


def pretty_name():
    return __pretty_name__


def pretty_status():
    if _selected_de:
        de_label = _selected_de
        if _config:
            for d in _config.get("desktops", []):
                if d.get("id") == _selected_de:
                    de_label = d.get("label", _selected_de)
                    break
        return f"Desktop: {de_label}"
    return "Selecting desktop..."


def load_config():
    config = calamares.configuration
    if not config:
        return {
            "title": "Desktop Environment",
            "desktops": [
                {"id": "kde", "label": "KDE Plasma 6",
                    "description": "Most customizable, gaming-friendly.",
                    "display_manager": "sddm", "package_group": "kde-desktop"},
                {"id": "gnome", "label": "GNOME 47",
                    "description": "Polished, minimal setup.",
                    "display_manager": "gdm", "package_group": "gnome-desktop"},
                {"id": "hyprland", "label": "Hyprland",
                    "description": "Dynamic tiling, animations.",
                    "display_manager": "sddm", "package_group": "",
                    "extra_packages": ["hyprland", "waybar", "wofi", "foot"]},
                {"id": "sway", "label": "Sway",
                    "description": "i3-compatible tiling.",
                    "display_manager": "sddm", "package_group": "",
                    "extra_packages": ["sway", "waybar", "wofi", "foot"]},
                {"id": "xfce", "label": "XFCE 4.20",
                    "description": "Lightweight, traditional.",
                    "display_manager": "lightdm", "package_group": "xfce-desktop"},
                {"id": "cinnamon", "label": "Cinnamon",
                    "description": "Windows-like layout.",
                    "display_manager": "lightdm",
                    "package_group": "cinnamon-desktop"},
            ],
            "default": "kde"
        }
    return config


class DECard(QFrame):
    """Card widget for a single desktop environment option."""

    def __init__(self, de_data, parent=None):
        super().__init__(parent)
        self.de_id = de_data.get("id", "")
        self.de_data = de_data

        self.setFrameStyle(QFrame.StyledPanel | QFrame.Raised)
        self.setMinimumHeight(90)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.setCursor(Qt.PointingHandCursor)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 12, 16, 12)
        layout.setSpacing(4)

        # Title row
        top_row = QHBoxLayout()
        self.radio = QRadioButton(de_data.get("label", "Unknown"))
        font = QFont()
        font.setBold(True)
        font.setPointSize(11)
        self.radio.setFont(font)
        top_row.addWidget(self.radio)

        # Wayland badge
        if de_data.get("wayland", False):
            wayland_badge = QLabel("Wayland")
            wayland_badge.setStyleSheet("""
                background: rgba(127, 217, 98, 0.15);
                color: #7fd962;
                padding: 2px 8px;
                border-radius: 4px;
                font-size: 10px;
                font-weight: bold;
            """)
            top_row.addWidget(wayland_badge)

        # RAM badge
        ram = de_data.get("ram_requirement", 0)
        if ram:
            ram_badge = QLabel(f"{ram}MB RAM")
            ram_badge.setStyleSheet("""
                background: rgba(249, 181, 74, 0.15);
                color: #f9b54a;
                padding: 2px 8px;
                border-radius: 4px;
                font-size: 10px;
            """)
            top_row.addWidget(ram_badge)

        top_row.addStretch()
        layout.addLayout(top_row)

        # Description
        desc_label = QLabel(de_data.get("description", ""))
        desc_label.setWordWrap(True)
        desc_label.setStyleSheet("color: #888; font-size: 11px;")
        desc_label.setContentsMargins(20, 0, 0, 0)
        layout.addWidget(desc_label)

    def set_selected(self, selected):
        self.radio.setChecked(selected)
        if selected:
            self.setStyleSheet("DECard { border: 2px solid #39bae6; border-radius: 8px; background: rgba(57, 186, 230, 0.05); }")
        else:
            self.setStyleSheet("DECard { border: 1px solid #333; border-radius: 8px; }")


class DESelectionWidget(QWidget):
    """Main widget for the desktop environment selection screen."""

    def __init__(self, config, parent=None):
        super().__init__(parent)
        self.config = config
        self.selected_de = config.get("default", "kde")
        self.de_cards = {}
        self.button_group = QButtonGroup(self)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        # Title
        title = QLabel(config.get("title", "Desktop Environment"))
        title_font = QFont()
        title_font.setPointSize(16)
        title_font.setBold(True)
        title.setFont(title_font)
        layout.addWidget(title)

        # Subtitle
        subtitle = QLabel("Pick your desktop environment. You can switch or install additional DEs later.")
        subtitle.setStyleSheet("color: #888; font-size: 12px;")
        subtitle.setWordWrap(True)
        layout.addWidget(subtitle)

        # Recommended badge based on selected profile
        gs = calamares.globalstorage
        selected_profile = gs.value("distroProfile") if gs else None
        if selected_profile:
            recommended = self.get_recommended_desktops(selected_profile)
            if recommended:
                rec_label = QLabel(f"Recommended for your profile ({selected_profile}): {', '.join(recommended)}")
                rec_label.setStyleSheet("color: #7fd962; font-size: 12px; font-weight: bold; padding: 8px;")
                layout.addWidget(rec_label)

        # Scrollable cards
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)

        scroll_content = QWidget()
        scroll_layout = QVBoxLayout(scroll_content)
        scroll_layout.setSpacing(8)
        scroll_layout.setContentsMargins(0, 0, 0, 0)

        desktops = config.get("desktops", [])
        default_id = config.get("default", "kde")

        for de in desktops:
            card = DECard(de)
            did = de.get("id", "")

            if did == default_id:
                card.set_selected(True)
                self.selected_de = did

            card.mousePressEvent = lambda e, c=card, d=did: self.select_de(d, c)
            card.radio.toggled.connect(lambda checked, d=did, c=card: self.select_de(d, c) if checked else None)

            self.button_group.addButton(card.radio)
            self.de_cards[did] = card
            scroll_layout.addWidget(card)

        scroll_layout.addStretch()
        scroll.setWidget(scroll_content)
        layout.addWidget(scroll)

        self.save_selection()

    def get_recommended_desktops(self, profile_id):
        """Get list of desktop IDs recommended for the selected profile."""
        desktops = self.config.get("desktops", [])
        recommended = []
        for de in desktops:
            rec_for = de.get("recommended_for", [])
            if profile_id in rec_for:
                recommended.append(de.get("label", de.get("id", "")))
        return recommended

    def select_de(self, de_id, card):
        self.selected_de = de_id
        for did, c in self.de_cards.items():
            c.set_selected(did == de_id)
        self.save_selection()

    def save_selection(self):
        global _selected_de
        _selected_de = self.selected_de

        gs = calamares.globalstorage
        if gs:
            gs.insert("distroDE", self.selected_de)

        # Find DE metadata
        desktops = self.config.get("desktops", [])
        de_meta = None
        for d in desktops:
            if d.get("id") == self.selected_de:
                de_meta = d
                break

        if gs and de_meta:
            gs.insert("distroDisplayManager", de_meta.get("display_manager", "sddm"))
            gs.insert("distroDEPackageGroup", de_meta.get("package_group", ""))
            gs.insert("distroDEExtraPackages", de_meta.get("extra_packages", []))
            gs.insert("distroDEWayland", de_meta.get("wayland", False))

        # Write context file
        context_dir = "/tmp/distro-install-context"
        os.makedirs(context_dir, exist_ok=True)
        context_file = os.path.join(context_dir, "de.conf")
        with open(context_file, "w") as f:
            f.write(f"DISTRO_DE={self.selected_de}\n")
            if de_meta:
                f.write(f"DISTRO_DISPLAY_MANAGER={de_meta.get('display_manager', 'sddm')}\n")
                f.write(f"DISTRO_DE_PACKAGE_GROUP={de_meta.get('package_group', '')}\n")
                f.write(f"DISTRO_DE_WAYLAND={'true' if de_meta.get('wayland', False) else 'false'}\n")
                extra = de_meta.get("extra_packages", [])
                if extra:
                    f.write(f"DISTRO_DE_EXTRA_PACKAGES={' '.join(extra)}\n")


def run():
    global _config
    _config = load_config()

    if HAS_PYQT:
        widget = DESelectionWidget(_config)
        calamares.ui.widget(widget)
    else:
        global _selected_de
        _selected_de = _config.get("default", "kde")

        gs = calamares.globalstorage
        if gs:
            gs.insert("distroDE", _selected_de)

        context_dir = "/tmp/distro-install-context"
        os.makedirs(context_dir, exist_ok=True)
        with open(os.path.join(context_dir, "de.conf"), "w") as f:
            f.write(f"DISTRO_DE={_selected_de}\n")

        calamares.utils.debug(f"[de-select] No PyQt, using default: {_selected_de}")

    return None
