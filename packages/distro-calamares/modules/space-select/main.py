#!/usr/bin/env python3
"""
KAAL OS — Calamares Space Selection Module

A Calamares view module that lets the user choose their default KAAL Space
during installation. The selection is stored in global storage and written
to /etc/kaal/spaces/default-space on the target system.

This module appears between the DE selection and the bootloader selection
in the Calamares install flow.
"""


import libcalamares

from PyQt5.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QFrame
)
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QFont, QColor, QPalette

# Space definitions
SPACES = [
    {
        "name": "gaming",
        "display_name": "Gaming",
        "description": "Performance mode for gaming. Max CPU/GPU, low-latency audio, game launchers, DND notifications.",
        "icon": "🎮",
        "color": "#FF6B35",
    },
    {
        "name": "development",
        "display_name": "Development",
        "description": "Development environment with IDEs, containers (Docker/Distrobox), terminal tools, balanced power.",
        "icon": "💻",
        "color": "#4A90D9",
    },
    {
        "name": "power",
        "display_name": "Power User",
        "description": "Full system access. All tools exposed, tiling WM, SSH enabled, verbose logging, system monitors.",
        "icon": "⚡",
        "color": "#9B59B6",
    },
    {
        "name": "normal",
        "display_name": "Normal",
        "description": "Everyday computing. Clean desktop, daily apps, power saving, simple and friendly UI.",
        "icon": "🏠",
        "color": "#2ECC71",
    },
]

DEFAULT_SPACE = "normal"

# Configuration key
CONFIG_KEY = "defaultSpace"


def pretty_name():
    return "KAAL Spaces"


class SpaceOption(QFrame):
    """A selectable option card for a single space."""

    def __init__(self, space_info: dict, parent=None):
        super().__init__(parent)
        self.space_name = space_info["name"]
        self.space_info = space_info
        self.setFrameShape(QFrame.Shape.Box)
        self.setFixedHeight(140)
        self.setMinimumWidth(300)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 15, 20, 15)

        # Header: icon + name
        header = QHBoxLayout()
        icon_label = QLabel(space_info["icon"])
        icon_label.setFont(QFont("Sans", 28))
        header.addWidget(icon_label)

        name_label = QLabel(space_info["display_name"])
        name_label.setFont(QFont("Sans", 16, QFont.Weight.Bold))
        header.addWidget(name_label)
        header.addStretch()

        layout.addLayout(header)

        # Description
        desc_label = QLabel(space_info["description"])
        desc_label.setWordWrap(True)
        desc_label.setFont(QFont("Sans", 10))
        desc_label.setStyleSheet("color: #888;")
        layout.addWidget(desc_label)

        self._update_style(False)

    def _update_style(self, selected: bool):
        color = self.space_info["color"]
        if selected:
            self.setStyleSheet(f"""
                SpaceOption {{
                    border: 3px solid {color};
                    border-radius: 10px;
                    background-color: rgba({int(color[1:3], 16)},
                                           {int(color[3:5], 16)},
                                           {int(color[5:7], 16)}, 25);
                }}
            """)
        else:
            self.setStyleSheet("""
                SpaceOption {
                    border: 2px solid #333;
                    border-radius: 10px;
                    background-color: #1a1a1a;
                }
                SpaceOption:hover {
                    border: 2px solid #555;
                    background-color: #222;
                }
            """)

    def set_selected(self, selected: bool):
        self._update_style(selected)


class SpaceSelectView(QWidget):
    """Main view for space selection."""

    def __init__(self, config):
        super().__init__()
        self.config = config
        self.selected_space = config.get(CONFIG_KEY, DEFAULT_SPACE)
        self.options = {}

        layout = QVBoxLayout(self)
        layout.setContentsMargins(40, 20, 40, 20)
        layout.setSpacing(15)

        # Title
        title = QLabel("Choose Your KAAL Space")
        title.setFont(QFont("Sans", 22, QFont.Weight.Bold))
        layout.addWidget(title)

        subtitle = QLabel(
            "Select a default space for your KAAL OS installation. "
            "You can switch between spaces at any time after installation."
        )
        subtitle.setFont(QFont("Sans", 11))
        subtitle.setWordWrap(True)
        subtitle.setStyleSheet("color: #888;")
        layout.addWidget(subtitle)

        # Space option cards
        cards_layout = QHBoxLayout()
        cards_layout.setSpacing(15)

        for space in SPACES:
            option = SpaceOption(space)
            option.mousePressEvent = lambda e, s=space["name"]: self._select(s)
            self.options[space["name"]] = option
            cards_layout.addWidget(option)

        layout.addLayout(cards_layout)

        # Selected info
        self.info_label = QLabel()
        self.info_label.setFont(QFont("Sans", 11))
        self.info_label.setStyleSheet("color: #4A90D9; padding: 10px;")
        layout.addWidget(self.info_label)

        layout.addStretch()

        # Update selection display
        self._update_selection_display()

    def _select(self, space_name: str):
        self.selected_space = space_name
        for name, option in self.options.items():
            option.set_selected(name == space_name)
        self._update_selection_display()

    def _update_selection_display(self):
        for space in SPACES:
            if space["name"] == self.selected_space:
                self.info_label.setText(
                    f"✓ Selected: {space['display_name']} — {space['description']}"
                )
                break

    def get_selected_space(self) -> str:
        return self.selected_space


class StepSpaceSelect:
    """Calamares Python view module for space selection."""

    def __init__(self):
        self.widget = None
        self.config = {}

    def prettyName(self):
        return pretty_name()

    def prettyStatus(self):
        return "Selecting KAAL Space"

    def isFormEnabled(self):
        return True

    def widgetConfiguration(self):
        return {}

    def setConfigurationMap(self, config_map):
        self.config = config_map or {}

    def createWidget(self, parent):
        # Apply dark theme
        palette = QPalette()
        palette.setColor(QPalette.ColorRole.Window, QColor("#0d0d0d"))
        palette.setColor(QPalette.ColorRole.WindowText, QColor("#ffffff"))
        parent.setPalette(palette)

        self.widget = SpaceSelectView(self.config)
        return self.widget

    def onLeave(self):
        """Called when user clicks Next — store selection in global storage."""
        if self.widget:
            selected = self.widget.get_selected_space()
            libcalamares.globalstorage.insert("kaalDefaultSpace", selected)
            libcalamares.globalstorage.insert("kaalSpaceSelected", True)

            # Also set the install context
            libcalamares.globalstorage.insert(
                "kaalSpaceConfig",
                {
                    "default_space": selected,
                    "auto_switch_enabled": True,
                }
            )

            libcalamares.utils.debug(
                f"KAAL Spaces: user selected '{selected}' as default space"
            )

    def jobs(self):
        """Return job modules to execute on target system."""
        # We don't define jobs here — the post-install shell scripts
        # read from global storage and write the config.
        return []


def getstep():
    return StepSpaceSelect()
