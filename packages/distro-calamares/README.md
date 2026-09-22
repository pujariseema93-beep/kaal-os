# KAAL OS Calamares Plugins

Custom Calamares installer modules for KAAL OS — profile selection, desktop environment selection, and bootloader selection screens.

## What This Package Does

These are real Python Calamares view/job modules that add custom screens to the installer:

1. **profile-select** — User picks a software profile (Gaming, Developer, Power User, Daily, Minimal, Custom)
2. **de-select** — User picks a desktop environment (KDE, GNOME, Hyprland, Sway, XFCE, Cinnamon)
3. **bootloader-select** — User picks a bootloader (GRUB2 or systemd-boot)
4. **distro-context** — Aggregates all selections into a context file for post-install scripts

## File Structure

```
distro-calamares/
├── settings.conf                         — Master Calamares config (module sequence)
├── modules/
│   ├── profile-select/
│   │   ├── module.desc                   — Module descriptor
│   │   ├── profile-select.conf           — Profile definitions (6 profiles)
│   │   └── main.py                       — Python view module with PyQt5 UI
│   ├── de-select/
│   │   ├── module.desc                   — Module descriptor
│   │   ├── de-select.conf                — DE definitions (6 desktops)
│   │   └── main.py                       — Python view module with PyQt5 UI
│   ├── bootloader-select/
│   │   ├── module.desc                   — Module descriptor
│   │   ├── bootloader-select.conf        — Bootloader options (2)
│   │   └── main.py                       — Python view module with PyQt5 UI
│   ├── distro-context/
│   │   ├── module.desc                   — Module descriptor
│   │   ├── distro-context.conf           — Context file paths
│   │   └── main.py                       — Python job module (no UI)
│   └── distro-post-install.conf          — Shellprocess config (runs 7 scripts)
├── branding/
│   └── distro-default/
│       └── branding.desc                 — Installer branding (placeholder)
└── README.md
```

## How It Works

### Installation Flow (User's Perspective)

```
Welcome
  → Profile Selection (custom screen: Gaming / Developer / Power User / Daily / Minimal / Custom)
  → Desktop Selection (custom screen: KDE / GNOME / Hyprland / Sway / XFCE / Cinnamon)
  → Locale + Keyboard
  → Partitioning
  → Bootloader Selection (custom screen: GRUB2 / systemd-boot)
  → User Creation
  → Summary
  → INSTALL
    → distro-context writes /etc/distro-bootloader/install-context.conf
    → 7 post-install scripts run, each sourcing the context file
    → GPU detection, DE install, profile install, bootloader setup, auto-update, tuning, finalize
  → Finished
```

### Data Flow (How Selections Reach Post-Install Scripts)

```
User selects "Gaming" profile
  → profile-select/main.py
    → stores in Calamares global storage: gs["distroProfile"] = "gaming"
    → writes /tmp/distro-install-context/profile.conf

User selects "KDE Plasma 6"
  → de-select/main.py
    → stores: gs["distroDE"] = "kde", gs["distroDisplayManager"] = "sddm"
    → writes /tmp/distro-install-context/de.conf

User selects "GRUB2"
  → bootloader-select/main.py
    → stores: gs["distroBootloader"] = "grub2"
    → writes /tmp/distro-install-context/bootloader.conf

distro-context/main.py runs (job module)
  → reads ALL selections from global storage + individual .conf files
  → writes single aggregated file: /etc/distro-bootloader/install-context.conf
     DISTRO_PROFILE=gaming
     DISTRO_DE=kde
     DISTRO_DISPLAY_MANAGER=sddm
     DISTRO_BOOTLOADER=grub2
     ...

Post-install scripts run:
  source /etc/distro-bootloader/install-context.conf
  → $DISTRO_PROFILE = "gaming"
  → $DISTRO_DE = "kde"
  → $DISTRO_BOOTLOADER = "grub2"
  → scripts use these to install the right packages
```

## Installation (For the ISO Build)

Copy these files to the live image filesystem:

```bash
# Modules go to /usr/lib/calamares/modules/
cp -r modules/* /usr/lib/calamares/modules/

# Settings go to /etc/calamares/
cp settings.conf /etc/calamares/settings.conf
cp modules/distro-post-install.conf /etc/calamares/modules/distro-post-install.conf

# Branding goes to /usr/lib/calamares/branding/
cp -r branding/distro-default /usr/lib/calamares/branding/
```

## Module API Reference

### View Modules (profile-select, de-select, bootloader-select)

Each view module defines:

- `pretty_name()` → str: sidebar label
- `pretty_status()` → str: sidebar status text
- `run()` → None: creates the QWidget and registers it with Calamares

The widget:
- Reads config from the `.conf` file via `calamares.configuration`
- Creates card-style radio button selection UI
- On selection: stores in `calamares.globalstorage` + writes context file
- Fallback: if PyQt5 unavailable, uses default value from config

### Job Module (distro-context)

- `run()` → None: reads all global storage keys, writes aggregated context file
- No UI — runs silently during installation
- Writes to both temp dir (for live system) and target root (for installed system)

## Customizing

### Adding a New Profile

1. Edit `modules/profile-select/profile-select.conf`
2. Add a new entry under `profiles:` with id, label, description, icon, packages_file
3. Create the corresponding `.list` file in the ISO builder's `profiles/` directory

### Adding a New Desktop Environment

1. Edit `modules/de-select/de-select.conf`
2. Add a new entry under `desktops:` with id, label, description, display_manager, etc.
3. Add a case statement in `scripts/02-de-install.sh`

### Changing Module Order

Edit `settings.conf` — move modules within the `show:` or `exec:` sequences.

## What's NOT Done Yet (Phase 5)

- **Branding assets**: logo, background, slide images (currently empty strings)
- **QML slides**: animated slides shown during installation
- **Translations**: all strings are English-only
- **Custom QSS**: full Qt stylesheet for the installer (basic colors defined)

## Requirements

- Calamares 3.3+ (installed in the live image)
- Python 3.12+ (comes with Fedora)
- PyQt5 or PyQt6 (for the UI — falls back to defaults if unavailable)
