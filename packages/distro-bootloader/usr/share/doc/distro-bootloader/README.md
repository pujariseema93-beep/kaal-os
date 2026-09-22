# KAAL OS Bootloader Base

The bootloader package for KAAL OS — a Fedora-based Linux distribution for gamers, power users, developers, and daily life.

## What This Package Does

This package provides the complete bootloader infrastructure for the distro:

- **GRUB2** as the default bootloader (Fedora-standard)
- **systemd-boot** as an alternative (simpler, faster, UEFI-only)
- **Dracut** initramfs configuration with GPU driver pre-loading
- **Automatic GPU detection** that sets the correct kernel parameters
- **Btrfs snapshot boot entries** for rollback recovery
- **Kernel-install hooks** that auto-update boot entries on kernel changes
- **Fallback/safe-mode entries** that boot without GPU drivers

## File Structure

```
etc/
  default/
    grub                              — Main GRUB2 configuration
    grub.d/
      10-distro-gpu.conf              — GPU-specific kernel parameter definitions
      20-distro-resume.conf           — Hibernate resume config (auto-populated)
  grub.d/
      06-distro-gpu-params            — GRUB script: detects GPU, injects params
      07-distro-theme                 — GRUB script: theme/branding (placeholder)
      25-distro-snapshots             — GRUB script: btrfs snapshot entries
  dracut.conf.d/
      10-distro-gpu.conf              — Include GPU drivers in initramfs
      20-distro-filesystem.conf       — Btrfs, LUKS, NVMe, zram support
      30-distro-base.conf             — Plymouth, compression, base modules

usr/
  libexec/distro-bootloader/
      distro-bootloader-setup         — Main setup/config/switch script
      90-distro-kernel-install        — kernel-install hook (auto-update entries)
  share/distro-bootloader/
    systemd-boot/
      loader.conf                     — systemd-boot main config
      entry-distro.conf.template      — Main boot entry template
      entry-distro-fallback.conf.template — Fallback/safe-mode entry
    kernel-params/
      REFERENCE.md                    — Full kernel parameter documentation
```

## Key Features

### GPU Auto-Detection

The `06-distro-gpu-params` GRUB script runs `lspci` during `grub2-mkconfig` and detects:
- NVIDIA RTX 40-series+ → adds `nvidia-drm.modeset=1`, `modprobe.blacklist=nouveau`, etc.
- AMD RDNA2+ → adds `amdgpu.ppfeaturemask=0xffffffff`, `rd.driver.pre=amdgpu`
- Intel iGPU → adds `i915.enable_guc=3`, `i915.fastboot=1`
- Hybrid (dual GPU) → applies both discrete and integrated params

### Gaming-Optimized Kernel Parameters

Always applied:
- `split_lock_detect=off` — fixes performance in emulators/Wine
- `preempt=full` — low latency for gaming
- `transparent_hugepage=madvise` — avoids latency spikes
- `mitigations=off` — disables CPU mitigations for max performance (configurable)

### Btrfs Snapshot Recovery

If snapper or timeshift is installed and the root filesystem is btrfs, snapshot boot entries appear in the GRUB menu. This allows booting into a pre-update snapshot if an update breaks the system.

### Dual Bootloader Support

GRUB2 is the default. Users can switch to systemd-boot via:
```bash
distro-bootloader-setup --switch systemd-boot
```

systemd-boot is simpler and faster but UEFI-only. GRUB2 supports both UEFI and BIOS.

### Fallback / Safe Mode

Both GRUB and systemd-boot entries include a fallback entry that boots with:
- `nomodeset` — basic framebuffer, no GPU drivers
- `rd.driver.blacklist=nvidia,nouveau` — prevents GPU drivers from loading
- `loglevel=7` — full debug logging

This ensures the system can always boot to a working TTY, even if GPU drivers are completely broken.

## Usage

```bash
# Install GRUB2 (default)
distro-bootloader-setup --install grub

# Install systemd-boot
distro-bootloader-setup --install systemd-boot

# Switch between bootloaders
distro-bootloader-setup --switch grub
distro-bootloader-setup --switch systemd-boot

# Regenerate config + initramfs (after GPU change or kernel param edit)
distro-bootloader-setup --regenerate

# Detect GPU and show kernel params
distro-bootloader-setup --detect-gpu

# Show current status
distro-bootloader-setup --status
```

## Boot Flow

```
Power On
  → UEFI/BIOS
    → Bootloader (GRUB2 or systemd-boot)
      → GPU detection (lspci in GRUB script)
      → Kernel + initramfs loaded with GPU params
        → Dracut initramfs: pre-loads GPU drivers
        → Mount root (btrfs with snapshot subvolume)
          → systemd init
            → Plymouth boot splash (theme TBD)
            → Display manager (SDDM/GDM)
              → Desktop session
```

## What's NOT Done Yet (Deferred to Phase 5)

- Custom GRUB theme (background, boot logo, menu styling)
- Custom Plymouth boot splash animation
- Custom systemd-boot theme
- SDDM/GDM login screen theme
- Distro name (currently `KAAL OS` placeholder)
- RPM spec file for packaging

## Requirements

- Fedora 40+ base (or equivalent)
- GRUB2 (`grub2-tools`, `grub2-efi-x64`, `shim-x64`)
- Dracut (`dracut`)
- systemd-boot (`systemd-udev`, `systemd-bootctl`) — optional, for alternative bootloader
- lspci (`pciutils`) — for GPU detection
- Btrfs tools (`btrfs-progs`) — for snapshot boot support
- Snapper or Timeshift — for snapshot management
