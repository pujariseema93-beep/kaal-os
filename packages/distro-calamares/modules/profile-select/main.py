#!/usr/bin/env python3
# =============================================================================
# main.py — Calamares View Module: Profile Selection
# =============================================================================
# This is a Calamares Python view module. It displays a screen during
# installation where the user selects their software profile (Gaming,
# Developer, Power User, Daily Life, Minimal, or Custom).
#
# The selection is stored in the Calamares global storage under the key
# "distroProfile" and also written to a temp file that the post-install
# scripts can read.
#
# Calamares Python view modules must define:
#   - pretty_status() -> str     : sidebar status text
#   - run() -> None              : called when module is activated
#
# View modules interact with the UI through the Calamares Python bindings,
# which provide the `calamares` module with access to global storage,
# the view manager, and Qt widgets.
#
# Place this file at:
#   /usr/lib/calamares/modules/profile-select/main.py
# =============================================================================

import calamares
import os

# Try to import PyQt for the UI
try:
    from PyQt5.QtWidgets import (
        QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
        QButtonGroup, QRadioButton, QScrollArea, QFrame, QSizePolicy
    )
    from PyQt5.QtCore import Qt
    from PyQt5.QtGui import QFont, QIcon
    HAS_PYQT = True
except ImportError:
    HAS_PYQT = False

# ---- Module metadata ----
__pretty_name__ = "Software Profile Selection"
__short_description__ = "Choose your software profile"

# ---- Global state ----
_selected_profile = None
_config = None
_profile_widgets = {}


def pretty_name():
    """Name shown in the Calamares sidebar."""
    return __pretty_name__


def pretty_status():
    """Status text shown in the sidebar."""
    if _selected_profile:
        return f"Profile: {_selected_profile}"
    return "Selecting profile..."


# =============================================================================
# Configuration Loader
# =============================================================================

def load_config():
    """Load the module configuration from the conf file."""
    config = calamares.configuration
    if not config:
        # Fallback defaults
        return {
            "title": "Software Profile",
            "profiles": [
                {"id": "gaming", "label": "Gaming", "description": "Steam, Proton, emulators, performance tools."},
                {"id": "developer", "label": "Developer", "description": "IDEs, languages, containers, terminal tools."},
                {"id": "power-user", "label": "Power User", "description": "Tiling WMs, system tools, customization."},
                {"id": "daily", "label": "Daily Life", "description": "Browser, office, media, creative apps."},
                {"id": "minimal", "label": "Minimal", "description": "Base system + DE only."},
                {"id": "custom", "label": "Custom", "description": "Skip profile installation."},
            ],
            "default": "gaming"
        }
    return config


# =============================================================================
# Qt UI Widget
# =============================================================================

class ProfileCard(QFrame):
    """A card widget representing a single profile option."""

    def __init__(self, profile_data, parent=None):
        super().__init__(parent)
        self.profile_id = profile_data.get("id", "")
        self.profile_data = profile_data

        self.setFrameStyle(QFrame.StyledPanel | QFrame.Raised)
        self.setLineWidth(1)
        self.setMinimumHeight(80)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.setCursor(Qt.PointingHandCursor)


        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 12, 16, 12)
        layout.setSpacing(4)

        # Label row (radio + title)
        top_row = QHBoxLayout()

        self.radio = QRadioButton(profile_data.get("label", "Unknown"))
        font = QFont()
        font.setBold(True)
        font.setPointSize(11)
        self.radio.setFont(font)
        top_row.addWidget(self.radio)
        top_row.addStretch()
        layout.addLayout(top_row)

        # Description
        desc_label = QLabel(profile_data.get("description", ""))  # noqa: E501
        desc_label.setWordWrap(True)
        desc_label.setStyleSheet("color: #888; font-size: 11px;")
        desc_label.setContentsMargins(20, 0, 0, 0)
        layout.addWidget(desc_label)

    def set_selected(self, selected):
        self.radio.setChecked(selected)
        if selected:
            self.setStyleSheet("ProfileCard { border: 2px solid #39bae6; border-radius: 8px; background: rgba(57, 186, 230, 0.05); }")
        else:
            self.setStyleSheet("ProfileCard { border: 1px solid #333; border-radius: 8px; }")


class ProfileSelectionWidget(QWidget):
    """Main widget for the profile selection screen."""

    def __init__(self, config, parent=None):
        super().__init__(parent)
        self.config = config
        self.selected_profile = config.get("default", "gaming")
        self.profile_cards = {}
        self.button_group = QButtonGroup(self)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        # Title
        title = QLabel(config.get("title", "Software Profile"))
        title_font = QFont()
        title_font.setPointSize(16)
        title_font.setBold(True)
        title.setFont(title_font)
        layout.addWidget(title)

        # Subtitle
        subtitle = QLabel("Choose what kind of system you want. You can always change or add software later.")
        subtitle.setStyleSheet("color: #888; font-size: 12px;")
        subtitle.setWordWrap(True)
        layout.addWidget(subtitle)

        # Scrollable area for profile cards
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)

        scroll_content = QWidget()
        scroll_layout = QVBoxLayout(scroll_content)
        scroll_layout.setSpacing(8)
        scroll_layout.setContentsMargins(0, 0, 0, 0)

        # Create a card for each profile
        profiles = config.get("profiles", [])
        default_id = config.get("default", "gaming")

        for profile in profiles:
            card = ProfileCard(profile)
            pid = profile.get("id", "")

            if pid == default_id:
                card.set_selected(True)
                self.selected_profile = pid

            card.mousePressEvent = lambda e, c=card, p=pid: self.select_profile(p, c)
            card.radio.toggled.connect(lambda checked, p=pid, c=card: self.select_profile(p, c) if checked else None)

            self.button_group.addButton(card.radio)
            self.profile_cards[pid] = card
            scroll_layout.addWidget(card)

        scroll_layout.addStretch()
        scroll.setWidget(scroll_content)
        layout.addWidget(scroll)

        # Store the selected profile in global storage immediately
        self.save_selection()

    def select_profile(self, profile_id, card):
        """Handle profile selection."""
        self.selected_profile = profile_id

        # Update visual state of all cards
        for pid, c in self.profile_cards.items():
            c.set_selected(pid == profile_id)

        self.save_selection()

    def save_selection(self):
        """Save the selection to Calamares global storage."""
        global _selected_profile
        _selected_profile = self.selected_profile

        # Store in Calamares global storage
        gs = calamares.globalstorage
        if gs:
            gs.insert("distroProfile", self.selected_profile)

        # Also find the packages file for this profile
        profiles = self.config.get("profiles", [])
        packages_file = ""
        for p in profiles:
            if p.get("id") == self.selected_profile:
                packages_file = p.get("packages_file", "")
                break

        if gs:
            gs.insert("distroProfilePackagesFile", packages_file)

        # Write to temp file for post-install scripts
        context_dir = "/tmp/distro-install-context"
        os.makedirs(context_dir, exist_ok=True)
        context_file = os.path.join(context_dir, "profile.conf")
        with open(context_file, "w") as f:
            f.write(f"DISTRO_PROFILE={self.selected_profile}\n")
            f.write("DISTRO_PROFILE_PACKAGES_FILE="
             f"{packages_file}\n")


# =============================================================================
# Calamares Entry Points
# =============================================================================

def run():
    """
    Called by Calamares when the module is activated.
    For view modules, this creates and returns the widget.
    """
    global _config
    _config = load_config()

    if HAS_PYQT:
        widget = ProfileSelectionWidget(_config)
        calamares.ui.widget(widget)
    else:
        # Fallback: no UI, use default
        global _selected_profile
        _selected_profile = _config.get("default", "gaming")

        gs = calamares.globalstorage
        if gs:
            gs.insert("distroProfile", _selected_profile)

        # Write context file
        context_dir = "/tmp/distro-install-context"
        os.makedirs(context_dir, exist_ok=True)
        with open(os.path.join(context_dir, "profile.conf"), "w") as f:
            f.write(f"DISTRO_PROFILE={_selected_profile}\n")

        calamares.utils.debug(f"[profile-select] No PyQt available, using default: {_selected_profile}")

    return None
