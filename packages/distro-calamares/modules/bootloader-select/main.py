#!/usr/bin/env python3
# =============================================================================
# main.py — Calamares View Module: Bootloader Selection
# =============================================================================
# Lets the user choose between GRUB2 and systemd-boot.
# Place at: /usr/lib/calamares/modules/bootloader-select/main.py
# =============================================================================

import calamares
import os

try:
    from PyQt5.QtWidgets import (
        QWidget, QVBoxLayout, QHBoxLayout, QLabel,
        QButtonGroup, QRadioButton, QFrame, QSizePolicy
    )
    from PyQt5.QtCore import Qt
    from PyQt5.QtGui import QFont
    HAS_PYQT = True
except ImportError:
    HAS_PYQT = False

__pretty_name__ = "Bootloader"
_selected_bootloader = None
_config = None


def pretty_name():
    return __pretty_name__


def pretty_status():
    if _selected_bootloader:
        return f"Bootloader: {_selected_bootloader}"
    return "Selecting bootloader..."


def load_config():
    config = calamares.configuration
    if not config:
        return {
            "title": "Bootloader",
            "options": [
                {"id": "grub2", "label": "GRUB2", "description": "Default bootloader. UEFI + BIOS. Snapshot booting.", "recommended": True},
                {"id": "systemd-boot", "label": "systemd-boot", "description": "Simpler, faster, UEFI only.", "recommended": False},
            ],
            "default": "grub2"
        }
    return config


class BootloaderCard(QFrame):
    def __init__(self, bl_data, parent=None):
        super().__init__(parent)
        self.bl_id = bl_data.get("id", "")

        self.setFrameStyle(QFrame.StyledPanel | QFrame.Raised)
        self.setMinimumHeight(90)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.setCursor(Qt.PointingHandCursor)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 12, 16, 12)
        layout.setSpacing(4)

        top = QHBoxLayout()
        self.radio = QRadioButton(bl_data.get("label", "Unknown"))
        f = QFont()
        f.setBold(True)
        f.setPointSize(11)
        self.radio.setFont(f)
        top.addWidget(self.radio)

        if bl_data.get("recommended", False):
            rec = QLabel("Recommended")
            rec.setStyleSheet("background: rgba(57,186,230,0.15); color: #39bae6; padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: bold;")
            top.addWidget(rec)

        # Feature badges
        if bl_data.get("supports_uefi") and bl_data.get("supports_bios"):
            badge = QLabel("UEFI + BIOS")
        elif bl_data.get("supports_uefi"):
            badge = QLabel("UEFI only")
        else:
            badge = QLabel("BIOS only")
        badge.setStyleSheet("background: rgba(127,217,98,0.15); color: #7fd962; padding: 2px 8px; border-radius: 4px; font-size: 10px;")
        top.addWidget(badge)

        if bl_data.get("supports_snapshots"):
            snap = QLabel("Snapshots")
            snap.setStyleSheet("background: rgba(249,181,74,0.15); color: #f9b54a; padding: 2px 8px; border-radius: 4px; font-size: 10px;")
            top.addWidget(snap)

        top.addStretch()
        layout.addLayout(top)

        desc = QLabel(bl_data.get("description", ""))
        desc.setWordWrap(True)
        desc.setStyleSheet("color: #888; font-size: 11px;")
        desc.setContentsMargins(20, 0, 0, 0)
        layout.addWidget(desc)

    def set_selected(self, sel):
        self.radio.setChecked(sel)
        if sel:
            self.setStyleSheet("BootloaderCard { border: 2px solid #39bae6; border-radius: 8px; background: rgba(57,186,230,0.05); }")
        else:
            self.setStyleSheet("BootloaderCard { border: 1px solid #333; border-radius: 8px; }")


class BootloaderWidget(QWidget):
    def __init__(self, config, parent=None):
        super().__init__(parent)
        self.config = config
        self.selected = config.get("default", "grub2")
        self.cards = {}
        self.btn_group = QButtonGroup(self)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        title = QLabel(config.get("title", "Bootloader"))
        tf = QFont()
        tf.setPointSize(16)
        tf.setBold(True)
        title.setFont(tf)
        layout.addWidget(title)

        sub = QLabel("Choose your bootloader. GRUB2 is recommended for most users and supports btrfs snapshot rollback.")
        sub.setStyleSheet("color: #888; font-size: 12px;")
        sub.setWordWrap(True)
        layout.addWidget(sub)

        for opt in config.get("options", []):
            card = BootloaderCard(opt)
            oid = opt.get("id", "")
            if oid == self.selected:
                card.set_selected(True)
            card.mousePressEvent = lambda e, c=card, o=oid: self.select(o, c)
            card.radio.toggled.connect(lambda checked, o=oid, c=card: self.select(o, c) if checked else None)
            self.btn_group.addButton(card.radio)
            self.cards[oid] = card
            layout.addWidget(card)

        layout.addStretch()
        self.save()

    def select(self, bl_id, card):
        self.selected = bl_id
        for bid, c in self.cards.items():
            c.set_selected(bid == bl_id)
        self.save()

    def save(self):
        global _selected_bootloader
        _selected_bootloader = self.selected

        gs = calamares.globalstorage
        if gs:
            gs.insert("distroBootloader", self.selected)

        ctx_dir = "/tmp/distro-install-context"
        os.makedirs(ctx_dir, exist_ok=True)
        with open(os.path.join(ctx_dir, "bootloader.conf"), "w") as f:
            f.write(f"DISTRO_BOOTLOADER={self.selected}\n")


def run():
    global _config
    _config = load_config()

    if HAS_PYQT:
        widget = BootloaderWidget(_config)
        calamares.ui.widget(widget)
    else:
        global _selected_bootloader
        _selected_bootloader = _config.get("default", "grub2")
        gs = calamares.globalstorage
        if gs:
            gs.insert("distroBootloader", _selected_bootloader)
        os.makedirs("/tmp/distro-install-context", exist_ok=True)
        with open("/tmp/distro-install-context/bootloader.conf", "w") as f:
            f.write(f"DISTRO_BOOTLOADER={_selected_bootloader}\n")
        calamares.utils.debug(f"[bootloader-select] No PyQt, default: {_selected_bootloader}")

    return None
