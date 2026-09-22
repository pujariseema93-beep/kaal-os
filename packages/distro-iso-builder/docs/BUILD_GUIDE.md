# KAAL OS ISO Builder

Complete tooling for building the KAAL OS live ISO image from a Fedora base.

## What This Package Does

This package contains everything needed to build a bootable live ISO of KAAL OS:

- **Kickstart file** defining the complete image contents
- **Software profile package lists** (gaming, developer, power-user, daily, minimal)
- **Post-install scripts** that run during installation (GPU detection, DE install, auto-update, system tuning)
- **ISO build scripts** using livemedia-creator or kiwi-NG
- **Calamares installer configuration** with profile/DE selection screens
- **Live image customization** (autologin, desktop shortcuts, welcome app)

## File Structure

```
distro-iso-builder/
├── distro-live.ks                  — Kickstart file (defines the entire ISO)
├── build-iso.sh                    — Main ISO build script (livemedia-creator)
├── build-iso-kiwi.sh               — Alternative build script (kiwi-NG)
├── profiles/
│   ├── gaming.list                 — Gaming profile packages
│   ├── developer.list              — Developer profile packages
│   ├── power-user.list             — Power user profile packages
│   ├── daily.list                  — Daily life profile packages
│   └── minimal.list                — Minimal profile packages
├── scripts/
│   ├── 01-gpu-detect.sh            — GPU detection & driver setup
│   ├── 02-de-install.sh            — Desktop environment installation
│   ├── 03-profile-install.sh       — Software profile installation
│   ├── 04-bootloader-setup.sh      — Bootloader installation
│   ├── 05-auto-update-setup.sh     — Auto-update system configuration
│   ├── 06-system-tuning.sh         — Performance tuning
│   └── 07-finalize.sh              — Final cleanup & first-boot prep
├── config/
│   ├── live-image-config.sh        — Live image customization
│   └── calamares-modules.conf      — Calamares installer modules
├── kiwi/
│   └── distro-live.xml             — kiwi-NG appliance config (alternative)
└── docs/
    └── BUILD_GUIDE.md              — This file
```

## Quick Start

### Prerequisites

- **Host system**: Fedora 40+ (bare metal or VM)
- **Privileges**: Root (sudo)
- **Disk space**: ~20GB free
- **Packages**: `lorax`, `lorax-composer`, `xorriso`, `pykickstart`, `livecd-tools`

### Build the ISO

```bash
# 1. Install build dependencies
sudo dnf install lorax lorax-composer xorriso pykickstart livecd-tools

# 2. Run the build script
sudo ./build-iso.sh --releasever 42 --name "KAAL OS"

# 3. Wait (~30-60 minutes depending on hardware and network speed)

# 4. Find your ISO
ls -la results/*.iso
```

### Alternative: Build with kiwi-NG

```bash
sudo dnf install kiwi-cli kiwi-system-dependencies
sudo ./build-iso-kiwi.sh --name "KAAL OS"
```

### Write to USB

```bash
# Method 1: dd
sudo dd if=results/KAAL OS_20260908_live_x86_64.iso of=/dev/sdX bs=4M status=progress && sync

# Method 2: Fedora Media Writer
sudo FedoraMediaWriter results/KAAL OS_20260908_live_x86_64.iso

# Method 3: Ventoy (copy ISO to Ventoy-formatted USB)
cp results/KAAL OS_20260908_live_x86_64.iso /run/media/user/VENTOY/
```

## Build Options

```bash
sudo ./build-iso.sh [OPTIONS]

  --releasever   Fedora version (default: 42)
  --workdir      Build working directory (default: /var/tmp/distro-build)
  --resultdir    Output directory (default: ./results)
  --profile      Package profile: all, gaming, developer, power-user, daily, minimal
  --name         Distro name (default: KAAL OS)
  --compress     ISO compression: xz (default) or gzip
  --volid        ISO volume label (default: DISTRO_LIVE)
  --keep-workdir Don't delete workdir after build
```

## How It Works

### Build Flow

```
build-iso.sh
  → Pre-flight checks (root, tools, disk space)
  → Install build dependencies (lorax, xorriso, etc.)
  → Prepare kickstart (replace placeholders, validate)
  → Run livemedia-creator
    → Create chroot from Fedora repos
    → Install packages from kickstart %package section
    → Run %post scripts (configure system)
    → Create initramfs (dracut)
    → Install bootloader (GRUB2)
    → Create SquashFS live image
    → Generate bootable ISO
  → Post-build (checksums, verification, rename)
  → Cleanup
```

### Installation Flow (When user installs from the ISO)

```
User boots live ISO
  → GRUB2 menu → "Try KAAL OS Live" or "Install"
  → Live desktop loads (KDE Plasma, autologin as liveuser)
  → User double-clicks "Install KAAL OS"
  → Calamares installer launches:
    1. Welcome screen
    2. Profile selection (Gaming / Developer / Power User / Daily / Minimal / Custom)
    3. Desktop environment selection (KDE / GNOME / Hyprland / Sway / XFCE / Cinnamon)
    4. Bootloader selection (GRUB2 / systemd-boot)
    5. Partitioning (Btrfs + LUKS optional)
    6. User account creation
    7. Summary
    8. Installation (runs post-install scripts in order)
    9. Complete — reboot
  → First boot:
    → distro-first-boot.service runs
    → GPU detection & driver setup
    → Initramfs regeneration
    → Display manager enablement
    → zram configuration
    → Snapper/Btrfs snapshot setup
    → Auto-update service enabled
  → Desktop ready!
```

### Post-Install Script Execution Order

| # | Script | Purpose |
|---|--------|---------|
| 01 | `01-gpu-detect.sh` | Detects GPU via lspci, installs correct driver, configures kernel params |
| 02 | `02-de-install.sh` | Installs the selected desktop environment + display manager |
| 03 | `03-profile-install.sh` | Installs packages from the selected profile list |
| 04 | `04-bootloader-setup.sh` | Installs GRUB2 or systemd-boot, generates config + initramfs |
| 05 | `05-auto-update-setup.sh` | Configures boot-triggered update check service |
| 06 | `06-system-tuning.sh` | CPU governor, I/O scheduler, zram, sysctl, limits.conf |
| 07 | `07-finalize.sh` | Cleanup, first-boot service enablement, final GRUB/initramfs regen |

## Customization

### Adding a New Software Profile

1. Create a file in `profiles/` (e.g., `creator.list`)
2. List packages one per line, comments with `#`
3. Add the profile to `config/calamares-modules.conf` under `profile-select.profiles`
4. Rebuild the ISO

### Adding a New Desktop Environment

1. Add a case statement in `scripts/02-de-install.sh`
2. Add the DE to `config/calamares-modules.conf` under `de-select.desktops`
3. Rebuild the ISO

### Changing the Default Kernel Parameters

Edit `distro-live.ks` — the `GRUB_CMDLINE_LINUX` line in the `%post` section, or the GPU params in the bootloader package's `etc/default/grub.d/10-distro-gpu.conf`.

## What's NOT Done Yet (Deferred)

- **Distro name**: Still `KAAL OS` placeholder
- **Calamares branding**: Installer slides and UI (Phase 5)
- **GRUB/Plymouth theme**: Boot logo and splash (Phase 5)
- **RPM packaging**: These files should be packaged as RPMs (`distro-bootloader`, `distro-installer`, `distro-config`)
- **Custom Calamares modules**: The profile/DE selection screens need Python plugin code
- **CI/CD**: Automated builds via GitHub Actions or GitLab CI

## Troubleshooting

### Build fails with "No space left on device"
- Use `--workdir` to point to a disk with more space
- Use `--compress gzip` for faster (but larger) builds

### Kickstart validation fails
- Run `ksvalidator distro-live.ks` to see errors
- Common issues: missing `%end`, wrong package names for target Fedora version

### ISO doesn't boot
- Verify with `checkisomd5 --verbose your.iso`
- Try a different USB writing tool (Ventoy is most reliable)
- Check UEFI vs BIOS — the ISO supports both

### NVIDIA driver not building in live image
- This is expected — akmod builds on first boot
- The `distro-first-boot.service` handles this automatically
