# KAAL OS Hardware Configuration Package

Scripts that configure all hardware subsystems during installation — WiFi, Bluetooth, audio, power management, display, input devices, USB, and fonts.

## What This Package Does

9 hardware configuration scripts that run during the Calamares post-install phase (scripts 08-16), filling the gap between "system installed" and "everything works out of the box."

## Scripts

| # | Script | What It Configures |
|---|--------|-------------------|
| 08 | `firmware-setup.sh` | WiFi firmware (Intel/Realtek/MediaKit), Bluetooth firmware (Broadcom), webcam, sensors, fwupd |
| 09 | `network-setup.sh` | NetworkManager, WiFi, wpa_supplicant, hotspot, DNS (systemd-resolved), firewall, VPN, IPv6 |
| 10 | `bluetooth-setup.sh` | Bluetooth service, LDAC/aptX/AAC codec priority, Blueman, udev rules, audio pairing |
| 11 | `audio-setup.sh` | PipeWire low-latency (quantum=64), WirePlumber, Bluetooth audio, EasyEffects, ALSA fallback |
| 12 | `power-setup.sh` | Suspend/resume hooks, brightness, lid switch, CPU governor auto-switch (AC/battery), thermald, TLP |
| 13 | `display-setup.sh` | VRR (FreeSync/G-Sync), HDR, fractional scaling, multi-monitor — per-DE configs (KDE/GNOME/Hyprland/Sway/XFCE) |
| 14 | `input-setup.sh` | Touchpad (natural scroll, tap-to-click, gestures), Wacom tablet, keyboard backlight, game controller udev |
| 15 | `usb-setup.sh` | Auto-mount (udisks2), MTP (Android), PTP (cameras), Apple AFC, polkit rules, FUSE, smart cards |
| 16 | `fonts-setup.sh` | Latin/CJK/Indic/Arabic/emoji fonts, subpixel rendering, hinting, fontconfig, MS font aliases |

## Integration

These scripts slot into the existing post-install chain:

```
01-07: Core system (GPU, DE, profile, bootloader, auto-update, tuning, finalize)
08-16: Hardware (firmware, WiFi, Bluetooth, audio, power, display, input, USB, fonts)  ← NEW
```

**Updated files provided:**
- `config/distro-post-install-v2.conf` — Replaces the original post-install config, adds scripts 08-16
- `config/settings-v2.conf` — Replaces the original Calamares settings, same module order but references v2 config

## Installation

```bash
# Copy scripts to the ISO build
cp scripts/*.sh /usr/libexec/distro-installer/

# Copy updated Calamares config
cp config/distro-post-install-v2.conf /etc/calamares/modules/distro-post-install.conf
cp config/settings-v2.conf /etc/calamares/settings.conf

# Make scripts executable
chmod +x /usr/libexec/distro-installer/*.sh
```

## Key Design Decisions

### Audio
- PipeWire with quantum=64 (~1.3ms latency at 48kHz) — gaming-optimized default
- Users can switch to quantum=32 (~0.7ms) via tweak tool for pro audio
- Bluetooth codec priority: LDAC > aptX HD > aptX > AAC > SBC
- EasyEffects pre-installed for EQ and effects

### Power
- power-profiles-daemon is the primary daemon (Fedora default)
- TLP installed but disabled — users can switch via tweak tool
- CPU governor auto-switches: performance on AC, powersave on battery
- Resume hook restarts PipeWire/NetworkManager if they break after suspend

### Display
- VRR enabled by default for KDE, GNOME, and Hyprland
- Fractional scaling enabled for GNOME (experimental-features)
- Kanshi configured for Hyprland/Sway multi-monitor auto-switching

### Fonts
- Default sans-serif: Inter
- Default monospace: JetBrains Mono
- Default serif: Noto Serif
- Full CJK coverage (Noto CJK + Source Han)
- Full Indic coverage (Noto + Lohit for all 10 Indian scripts)
- MS font aliases (Arial→Liberation Sans, Calibri→Carlito)
- Subpixel rendering + slight hinting + LCD filter
