# KAAL Spaces — Custom Space Creation Guide

## Creating Custom Spaces

KAAL OS Spaces are not limited to the 4 built-in profiles. You can create
unlimited custom spaces from templates, clone existing ones, and share
them with other users.

## Quick Start

### Create from CLI

```bash
# Create a space from a template
kaal-space create my-study --template study

# Create interactively (no args — wizard prompts you)
kaal-space create

# List available templates
kaal-space templates
```

### Create from GUI

1. Launch **KAAL Spaces** from the app menu
2. Click the **"+" (New Space)** card at the end of the row
3. The Space Editor opens — fill in your settings
4. Click **Save Space**

### Edit an Existing Space

```bash
# Edit in terminal
kaal-space edit my-study

# Or use the GUI
kaal-space-editor my-study
```

## Available Templates

| Template | Description |
|----------|-------------|
| `blank` | Minimal starting point — all defaults, nothing configured |
| `study` | Distraction-free study mode: DND, reading tools, focus timer |
| `media` | Media center: VSync on, rich audio, streaming apps pinned |
| `creative` | Digital art/design: GPU acceleration, color management, tablet support |
| `security` | Security research: pentest tools, SSH, VMs, verbose logging |
| `kiosk` | Single-app kiosk: locked down, fullscreen, no distractions |

## CLI Commands

### Create
```bash
kaal-space create <name> [--template <template>]
```
Creates a new space from a template. Name must be lowercase, 2-32 chars,
letters/digits/hyphens, starting with a letter.

### Clone
```bash
kaal-space clone gaming gaming-laptop
```
Duplicates an existing space (including hooks) to a new name.

### Edit
```bash
kaal-space edit <name>
```
Opens the space config in `$EDITOR` (default: nano). After saving,
systemd targets are regenerated.

### Delete
```bash
kaal-space delete my-custom-space
```
Deletes a custom space. Built-in spaces cannot be deleted. You must
confirm by typing the space name.

### Export
```bash
kaal-space export my-study > my-study.json
kaal-space export my-study /path/to/my-study.json
```
Exports a space as JSON (including hooks). Share it with other users.

### Import
```bash
kaal-space import my-study.json
```
Imports a space from JSON. The space name comes from the JSON file.

### Regenerate Targets
```bash
kaal-space regenerate-targets
```
Regenerates all systemd target files. Run this if you manually edit
space config files outside the CLI/GUI.

## Space Editor GUI

The Space Editor (`kaal-space-editor`) provides a visual interface with
tabs for each category of settings:

### General Tab
- Display name, description, color picker

### System Tab
- CPU governor (performance/schedutil/ondemand/powersave)
- Energy performance preference (Intel EPP)
- GPU power profile and dedicated GPU forcing
- Audio quantum (16-8192 samples) and sample rate
- Compositor effects and VSync toggles
- Notifications mode (all/minimal/dnd/off)
- Bluetooth, SSH, network QoS toggles

### Services Tab
- Services to enable, disable, or restart when entering this space

### Desktop Tab
- Wallpaper path, panel layout, pinned apps
- Category show/hide for app menu

### Environment Tab
- Custom environment variables (KEY=VALUE per line)
- These are written to `/etc/environment.d/` for the session

### Hooks Tab
- Pre/post enter/exit hook script paths
- Hook scripts run at the right time during space transitions

### Raw Config Tab
- Direct INI editing for advanced users
- Changes here override the form fields on save

## How Dynamic Discovery Works

The daemon (`kaal-spaced`) discovers spaces by scanning `/etc/kaal/spaces/*.conf`
at runtime. There is no hardcoded list — any valid `.conf` file is a space.

When you create or delete a space:
1. The config file is created/removed in `/etc/kaal/spaces/`
2. Hook scripts are created/removed in `/usr/libexec/kaal-spaces/hooks/`
3. `generate-targets.sh` regenerates systemd targets for ALL spaces
4. `systemctl daemon-reload` picks up the new targets
5. The switcher GUI auto-discovers the new space within 3 seconds

## Space Config Format

All space configs use INI format with these sections:

```ini
[space]
name = My Custom Space
description = What this space does
color = #FF6B35
icon = /path/to/icon.svg

[system]
cpu_governor = schedutil
cpu_energy_perf = balance_performance
gpu_power_profile = auto
gpu_force_dedicated = false
audio_quantum = 256
audio_rate = 48000
compositor_effects = true
compositor_vsync = true
notifications = all
bluetooth = on
network_ssh = false
network_qos = false

[services]
enable = docker.service, podman.socket
disable = gamemoded.service
restart = pipewire.service

[desktop]
wallpaper = /path/to/wallpaper.jpg
panel_layout = normal
pinned_apps = firefox,code,terminal
show_categories = Network,Office
hide_categories = Game

[environment]
MY_VAR = value
EDITOR = code

[hooks]
pre_enter = /usr/libexec/kaal-spaces/hooks/my-space-pre_enter.sh
post_enter = /usr/libexec/kaal-spaces/hooks/my-space-post_enter.sh
pre_exit = /usr/libexec/kaal-spaces/hooks/my-space-pre_exit.sh
post_exit = /usr/libexec/kaal-spaces/hooks/my-space-post_exit.sh

[meta]
created_by = username
template = study
```

## Sharing Spaces

### Export
```bash
kaal-space export my-study ~/my-study.json
```

### Import (on another machine)
```bash
kaal-space import ~/my-study.json
```

The JSON includes the space config and all hook scripts. The recipient
gets an exact copy of your space.

## File Locations

```
/etc/kaal/spaces/
    *.conf                              # All space configs (built-in + custom)

/usr/share/kaal/spaces/templates/
    blank.conf                          # Empty template
    study.conf                           # Study template
    media.conf                           # Media center template
    creative.conf                        # Creative/design template
    security.conf                        # Security/pentest template
    kiosk.conf                           # Kiosk template

/usr/libexec/kaal-spaces/
    kaal-spaced                          # D-Bus daemon (v2, dynamic)
    apply-space.sh                       # Config application script
    generate-targets.sh                  # Systemd target generator
    hooks/                               # Hook scripts per space

/usr/lib/systemd/system/
    kaal-space-*.target                  # Auto-generated per space
    kaal-space-*-setup.service           # Auto-generated per space

/usr/bin/
    kaal-space                           # CLI (v2, with create/edit/clone/delete)
    kaal-space-switcher                  # GUI switcher (dynamic discovery)
    kaal-space-editor                    # GUI editor (create/edit custom spaces)
```
