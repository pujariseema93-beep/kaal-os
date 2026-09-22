#!/usr/bin/env python3
# =============================================================================
# main.py — Calamares Job Module: Distro Context Aggregator
# =============================================================================
# This is a JOB module (not a view module). It runs after all three
# selection modules (profile-select, de-select, bootloader-select) have
# completed. It reads all selections from Calamares global storage and
# writes them to a single context file that the post-install scripts
# can source as shell variables.
#
# The context file is written to BOTH:
#   1. /tmp/distro-install-context/distro-install.conf (for live system)
#   2. <target>/etc/distro-bootloader/install-context.conf (for installed system)
#
# The post-install scripts (01-gpu-detect.sh, 02-de-install.sh, etc.)
# source this file to get the user's selections as environment variables.
#
# Place at: /usr/lib/calamares/modules/distro-context/main.py
# =============================================================================

import calamares
import os
import json
from datetime import datetime

__pretty_name__ = "Save Installation Context"


def pretty_name():
    return __pretty_name__


def pretty_status():
    return "Saving installation context..."


def load_config():
    config = calamares.configuration or {}
    return {
        "context_file": config.get("context_file", "/etc/distro-bootloader/install-context.conf"),
        "temp_context_dir": config.get("temp_context_dir", "/tmp/distro-install-context"),
        "log_context": config.get("log_context", True),
    }


def run():
    """
    Main entry point. Reads all selections from global storage and
    writes them to context files.
    """
    config = load_config()
    gs = calamares.globalstorage

    # ---- Gather all selections from global storage ----
    context = {
        # From profile-select module
        "DISTRO_PROFILE": gs.value("distroProfile") or "gaming",
        "DISTRO_PROFILE_PACKAGES_FILE": gs.value("distroProfilePackagesFile") or "",

        # From de-select module
        "DISTRO_DE": gs.value("distroDE") or "kde",
        "DISTRO_DISPLAY_MANAGER": gs.value("distroDisplayManager") or "sddm",
        "DISTRO_DE_PACKAGE_GROUP": gs.value("distroDEPackageGroup") or "",
        "DISTRO_DE_EXTRA_PACKAGES": " ".join(gs.value("distroDEExtraPackages") or []),
        "DISTRO_DE_WAYLAND": "true" if gs.value("distroDEWayland") else "false",

        # From bootloader-select module
        "DISTRO_BOOTLOADER": gs.value("distroBootloader") or "grub2",

        # From space-select module
        "KAAL_DEFAULT_SPACE": gs.value("kaalDefaultSpace") or "normal",

        # System info from Calamares
        "DISTRO_INSTALL_DATE": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "DISTRO_HOSTNAME": gs.value("hostname") or "distro",

        # Partition info
        "DISTRO_ROOT_FS_TYPE": gs.value("rootFsType") or "btrfs",

        # User info
        "DISTRO_USER_NAME": gs.value("username") or "",
        "DISTRO_USER_REALNAME": gs.value("userRealName") or "",
        "DISTRO_USER_SHELL": gs.value("userShell") or "/bin/bash",
    }

    # ---- Also read from individual context files (in case modules wrote there) ----
    temp_dir = config["temp_context_dir"]
    for conf_file in ["profile.conf", "de.conf", "bootloader.conf"]:
        path = os.path.join(temp_dir, conf_file)
        if os.path.exists(path):
            try:
                with open(path, "r") as f:
                    for line in f:
                        line = line.strip()
                        if "=" in line and not line.startswith("#"):
                            key, val = line.split("=", 1)
                            # Don't overwrite global storage values, but fill in gaps
                            if key not in context or not context[key]:
                                context[key] = val
            except Exception as e:
                calamares.utils.warning(f"[distro-context] Could not read {path}: {e}")

    # ---- Write to temp context file (for live system post-install scripts) ----
    os.makedirs(temp_dir, exist_ok=True)
    temp_context_file = os.path.join(temp_dir, "distro-install.conf")
    write_context_file(temp_context_file, context)

    # ---- Write to target system (installed system) ----
    # Calamares provides the target root via global storage
    target_root = gs.value("rootMountPoint") or "/"
    target_context_path = config["context_file"]
    target_context_full = os.path.join(target_root, target_context_path.lstrip("/"))

    try:
        os.makedirs(os.path.dirname(target_context_full), exist_ok=True)
        write_context_file(target_context_full, context)
        calamares.utils.debug(f"[distro-context] Written to target: {target_context_full}")
    except Exception as e:
        calamares.utils.warning(f"[distro-context] Could not write to target: {e}")

    # ---- Write JSON version for programmatic access ----
    json_path = os.path.join(temp_dir, "distro-install.json")
    try:
        with open(json_path, "w") as f:
            json.dump(context, f, indent=2)
    except Exception as e:
        calamares.utils.warning(f"[distro-context] Could not write JSON: {e}")

    # ---- Log context ----
    if config.get("log_context", True):
        calamares.utils.debug("[distro-context] Installation context:")
        for key, val in context.items():
            calamares.utils.debug(f"  {key}={val}")

    # ---- Store in global storage for other modules ----
    gs.insert("distroContext", context)

    calamares.utils.debug("[distro-context] Context saved successfully")

    return None


def write_context_file(path, context):
    """Write the context as a shell-sourceable config file."""
    with open(path, "w") as f:
        f.write("# KAAL OS Installation Context\n")
        f.write("# Auto-generated by Calamares distro-context module\n")
        f.write(f"# Generated: {context.get('DISTRO_INSTALL_DATE', '')}\n")
        f.write("# This file is sourced by post-install scripts.\n")
        f.write("# DO NOT EDIT — regeneration will overwrite.\n")
        f.write("\n")

        for key, val in context.items():
            if val:
                f.write(f"{key}={val}\n")
            else:
                f.write(f"{key}=\n")
