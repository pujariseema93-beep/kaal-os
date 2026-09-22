# KAAL Spaces — Architecture & User Guide

## Overview

Kaal Spaces is a runtime profile system for KAAL OS that lets users switch between four distinct computing environments without rebooting. Each space reconfigures the CPU governor, GPU power profile, audio latency, compositor effects, running services, desktop layout, pinned apps, and environment variables — instantly.

## The Four Spaces

### 🎮 Gaming
Maximizes system performance for gaming.
- **CPU:** `performance` governor, Intel EPP set to `performance`
- **GPU:** Max power profile, dedicated GPU forced (NVIDIA PRIME)
- **Audio:** Quantum 64 samples (~1.3ms latency at 48kHz)
- **Compositor:** Effects off, VSync off (max FPS)
- **Services:** GameMode, Steam enabled; Docker, libvirtd disabled
- **Notifications:** Do Not Disturb
- **Pinned:** Steam, Lutris, Bottles, Heroic, MangoHud
- **Network:** QoS enabled (game traffic prioritized via `tc`)

### 💻 Development
Optimized for coding, building, and containerized workflows.
- **CPU:** `schedutil` governor (responsive scaling)
- **GPU:** Auto profile, no dedicated GPU forced
- **Audio:** Quantum 256 samples (normal latency)
- **Compositor:** Effects on, VSync on
- **Services:** Docker, Podman, libvirtd, Cockpit enabled
- **Notifications:** Minimal
- **Pinned:** VS Code, Terminal, DBeaver, Git, System Monitor
- **Environment:** `DEV_MODE=1`, `EDITOR=code`, `DOCKER_HOST` set

### ⚡ Power User
Exposes all system tools, full control, verbose logging.
- **CPU:** `schedutil` governor
- **GPU:** Balanced profile
- **Audio:** Quantum 128 samples
- **Services:** SSH, Cockpit, sysstat, thermald enabled
- **Notifications:** All
- **Pinned:** Terminal, htop, btop, GParted, dnfdragora, Tweaks
- **Environment:** `ROOT_TOOLS=1`, `SHOW_SYSTEM=1`, `VERBOSE=1`

### 🏠 Normal
Clean, simple, power-efficient for everyday computing.
- **CPU:** `powersave` governor
- **GPU:** Auto profile
- **Audio:** Quantum 1024 samples (power efficient)
- **Compositor:** Full effects, VSync on
- **Services:** Dev/gaming services disabled
- **Pinned:** Firefox, LibreOffice, Files, Text Editor, Music
- **Environment:** `SIMPLIFIED=1`, `HIDE_SYSTEM=1`, `POWER_SAVE=1`

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    User Input                         │
│  CLI (kaal-space)  │  GUI (switcher)  │  Auto-Switch  │
└────────┬───────────┴──────┬───────────┴──────┬───────┘
         │                  │                  │
         ▼                  ▼                  ▼
    ┌────────────────────────────────────────────────┐
    │           D-Bus: org.kaal.Spaces              │
    │              (kaal-spaced daemon)              │
    │                                                │
    │  SwitchSpace()  GetCurrentSpace()  ListSpaces()│
    │  SetDefaultSpace()  GetSpaceInfo()             │
    └───────────────────┬────────────────────────────┘
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
    ┌─────────┐  ┌────────────┐  ┌──────────┐
    │ Hooks   │  │ apply-     │  │ systemd  │
    │ (pre/post│  │ space.sh   │  │ targets  │
    │  enter/  │  │            │  │          │
    │  exit)   │  │ Reads conf │  │ Isolate  │
    └─────────┘  └──────┬─────┘  └──────────┘
                        │
    ┌───────────┬────────┼────────┬───────────┐
    ▼           ▼        ▼        ▼           ▼
┌────────┐┌────────┐┌────────┐┌────────┐┌──────────┐
│  CPU   ││  GPU   ││ Audio  ││Desktop ││ Services │
│Governor││ Power  ││PipeWire││ Panel  ││ Enable/  │
│ + EPP  ││Profile ││Quantum ││ Layout ││ Disable  │
└────────┘└────────┘└────────┘└────────┘└──────────┘
```

## How Switching Works

1. **User triggers switch** — via CLI (`kaal-space switch gaming`), GUI card click, or auto-switch rule
2. **D-Bus call** — `kaal-spaced` receives `SwitchSpace("gaming")`
3. **Pre-exit hooks** — current space runs its cleanup hooks
4. **systemd isolate** — `systemctl isolate kaal-space-gaming.target` activates the target
5. **apply-space.sh** — reads `/etc/kaal/spaces/gaming.conf` and applies all settings:
   - CPU governor via `/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor`
   - GPU power via `nvidia-smi` or AMD sysfs
   - PipeWire quantum via config overlay + service restart
   - Service enable/disable via `systemctl`
   - Desktop panel layout via `gsettings`/`kwriteconfig5`
   - Environment variables via `/etc/environment.d/`
   - Network QoS via `tc`
6. **Post-enter hooks** — new space runs its setup hooks
7. **State update** — `/run/kaal/current-space` updated, last space persisted
8. **D-Bus signal** — `SpaceChanged(old, new)` emitted for GUI to update
9. **Desktop notification** — "KAAL Space: Gaming" shown to user

## File Layout

```
etc/
  kaal/spaces/
    gaming.conf          # Gaming space configuration
    development.conf     # Development space configuration
    power.conf           # Power User space configuration
    normal.conf          # Normal space configuration
    auto-switch.conf     # Auto-switch rules
  dbus-1/system.d/
    org.kaal.Spaces.conf # D-Bus access policy
  xdg/autostart/
    kaal-space-auto.desktop  # Auto-switch daemon autostart
  environment.d/
    50-kaal-space.conf   # Session environment (updated by daemon)

usr/
  bin/
    kaal-space            # CLI tool
    kaal-space-switcher   # Qt6 GUI app
  libexec/kaal-spaces/
    kaal-spaced           # D-Bus daemon (Python)
    apply-space.sh        # Space config application script
    kaal-space-auto       # Auto-switch daemon (Python)
    kaal-space-login      # Login space selector
    hooks/                # 16 hook scripts (4 per space × pre/post enter/exit)
      gaming-pre.sh
      gaming-post.sh
      gaming-pre-exit.sh
      gaming-post-exit.sh
      development-pre.sh
      ... (×4 per space)
    panels/               # Per-space panel layout scripts
      gaming.sh
      development.sh
      power.sh
      normal.sh
  lib/systemd/system/
    kaal-spaced.service           # Main daemon
    kaal-space-auto.service       # Auto-switch daemon
    kaal-space-gaming.target      # Gaming systemd target
    kaal-space-development.target # Development systemd target
    kaal-space-power.target       # Power User systemd target
    kaal-space-normal.target      # Normal systemd target
    kaal-space-gaming-setup.service       # One-shot setup
    kaal-space-development-setup.service # One-shot setup
    kaal-space-power-setup.service        # One-shot setup
    kaal-space-normal-setup.service      # One-shot setup
  share/
    applications/
      kaal-space-switcher.desktop  # App menu entry
    polkit-1/actions/
      org.kaal.spaces.policy       # Polkit auth rules
    kaal/spaces/
      gaming/icon.svg
      development/icon.svg
      power/icon.svg
      normal/icon.svg

scripts/
  17-spaces-setup.sh     # Post-install script for ISO builder

calamares/
  modules/space-select/
    main.py              # Calamares view module
    module.desc          # Module descriptor
```

## Usage

### CLI

```bash
# Show current space
kaal-space

# List all spaces
kaal-space list

# Switch to a space
kaal-space switch gaming
kaal-space switch development
kaal-space switch power
kaal-space switch normal

# Show space details
kaal-space info gaming

# Show full status
kaal-space status

# Set default space for next boot
kaal-space default gaming
```

### GUI

Launch **KAAL Spaces** from the application menu. Four colored cards appear — click any card to switch instantly. The active card is highlighted with its space color.

### Login

When configured with greetd or a display manager, the login screen shows a space selector. Choose a space before logging in to start your session in that space.

### Auto-Switch

The auto-switch daemon monitors system context and switches spaces based on rules in `/etc/kaal/spaces/auto-switch.conf`:

- **AC power plugged in** → switches to Gaming (or configured space)
- **Battery mode** → switches to Normal (or configured space)
- **Steam focused** → switches to Gaming
- **VS Code focused** → switches to Development
- **Terminal focused** → switches to Power User

Auto-switch can be disabled by setting `enabled = false` in the config.

## Integration with KAAL OS

### ISO Builder
Script `17-spaces-setup.sh` is added to the post-install chain after the existing 16 scripts. It:
- Enables `kaal-spaced.service` at boot
- Sets the default space from Calamares selection
- Creates state directories
- Installs placeholder icons

### Calamares Installer
The `space-select` view module appears between DE selection and bootloader selection. The user picks a card, and the selection flows through global storage to the post-install script.

### Boot Flow
1. `kaal-spaced.service` starts at boot
2. Reads last space from `/var/lib/kaal/spaces/last-space`
3. Runs `apply-space.sh` to restore that space's configuration
4. Runs pre/post-enter hooks
5. User session starts in the restored space

### Auto-Update
The auto-update timer checks for `kaal-spaces` package updates and new space configurations.

## Dependencies

### Required
- `python3-dbus` — D-Bus Python bindings
- `python3-gobject` — GLib main loop
- `python3-qt6` (PyQt6) — GUI switcher
- `dbus` — D-Bus system bus
- `systemd` — service management
- `polkit` — privilege escalation

### Optional (per-space)
- `gamemode` — Gaming space
- `pipewire`, `wireplumber` — Audio configuration
- `docker`, `podman` — Development space
- `cockpit` — Power User space
- `htop`, `btop` — Power User space
- `gsettings` (GNOME) / `kwriteconfig5` (KDE) — Desktop configuration
