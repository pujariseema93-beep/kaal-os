# KAAL OS — Complete Project Master Archive

A custom, fully customizable Linux distribution for gamers, power users, developers, and daily life. Built on Fedora 42.

## Archive Contents

```
distro-master/
├── README.md                           ← This file
├── docs/
│   ├── Distro_Specification.html       ← Full 15-section spec (v0.2) — visual, interactive
│   ├── Bootloader_Boot_Flow.html       ← Visual boot flow diagram + file map
│   ├── ISO_Build_Pipeline.html         ← Visual build pipeline + installation flow
│   └── distro-spec-build.py            ← Build script for the spec HTML (reusable)
│
└── packages/
    ├── distro-bootloader/              ← PACKAGE 1: Bootloader Base (15 files)
    ├── distro-iso-builder/             ← PACKAGE 2: ISO Builder (25 files)
    ├── distro-calamares/               ← PACKAGE 3: Calamares Plugins (24 files)
    ├── distro-hardware/                ← PACKAGE 4: Hardware Config (17 files)
    └── distro-ci/                      ← PACKAGE 5: CI/CD Pipeline (18 files)
```

**Total: 77 files across 6 packages**

---

## Package Summaries

### 1. Specification (docs/)
The master blueprint — 15 sections covering overview, hardware support matrix (NVIDIA RTX 40+, AMD RDNA2+, Intel 2015+), system architecture, GPU driver stack, 6 desktop environments, gaming stack, developer tools, daily life apps, package management (DNF5 + Flatpak + RPM Fusion), customization framework, auto-update on boot, system requirements, installation process, development roadmap, and boot/theme placeholders.

Open `docs/Distro_Specification.html` in a browser — it has a sticky table of contents and dark/light mode.

### 2. Bootloader Base (packages/distro-bootloader/)
Real GRUB2 + systemd-boot + dracut configuration with:
- Auto GPU detection via `lspci` during `grub2-mkconfig`
- NVIDIA modeset, nouveau blacklist, module pre-loading
- AMD power play features, Intel GuC/fastboot
- Gaming kernel params (split_lock_detect=off, preempt=full, mitigations=off)
- Btrfs snapshot boot entries for rollback
- Fallback/safe-mode entry with nomodeset
- `distro-bootloader-setup` script (install, switch, regenerate, status)
- kernel-install hook for auto-updating entries on kernel changes

### 3. ISO Builder (packages/distro-iso-builder/)
Complete ISO creation pipeline:
- `distro-live.ks` — kickstart file defining the entire image (~300 packages)
- `build-iso.sh` — livemedia-creator build script
- `build-iso-kiwi.sh` — alternative kiwi-NG build
- 5 software profile package lists (gaming, developer, power-user, daily, minimal)
- 7 post-install scripts (GPU detect, DE install, profile install, bootloader, auto-update, tuning, finalize)
- Calamares installer configuration
- Live image customization (autologin, desktop shortcuts)
- `BUILD_GUIDE.md` — full build instructions

### 4. Calamares Plugins (packages/distro-calamares/)
4 real Python modules with PyQt5 UI:
- `profile-select` — card-style screen for 6 software profiles
- `de-select` — card-style screen for 6 desktop environments with Wayland/RAM badges
- `bootloader-select` — GRUB2 vs systemd-boot selection
- `distro-context` — job module that aggregates all selections into a context file
- Master `settings.conf` chaining all modules in correct order
- Branding config (placeholder with distro color scheme)
- `distro-post-install.conf` — runs all 16 post-install scripts in order

### 5. Hardware Config (packages/distro-hardware/)
9 scripts covering all hardware subsystems:
- 08: Firmware (WiFi/Intel/Realtek, Bluetooth/Broadcom, webcam, sensors, fwupd)
- 09: Network/WiFi (NetworkManager, wpa_supplicant, hotspot, DNS, firewall, VPN, IPv6)
- 10: Bluetooth (service, LDAC/aptX/AAC codecs, Blueman, udev, audio pairing)
- 11: Audio/PipeWire (quantum=64 low-latency, WirePlumber, Bluetooth audio, EasyEffects)
- 12: Power (suspend/resume hooks, brightness, lid switch, CPU governor auto-switch, thermald, TLP)
- 13: Display (VRR, HDR, fractional scaling, multi-monitor — per-DE configs)
- 14: Input (touchpad gestures, Wacom, keyboard backlight, game controller udev)
- 15: USB/Auto-mount (udisks2, MTP/Android, PTP/cameras, Apple AFC, polkit, FUSE)
- 16: Fonts (50+ packages: Latin/CJK/Indic/Arabic/emoji, subpixel rendering, fontconfig)
- Updated `distro-post-install-v2.conf` and `settings-v2.conf` wiring all 16 scripts

### 6. CI/CD Pipeline (packages/distro-ci/)
Full automation:
- `validate.yml` — shellcheck, flake8, ksvalidator, yamllint, placeholder check, structure check
- `build-iso.yml` — builds ISO in Fedora 42 container, uploads as artifact
- `test-iso.yml` — boots ISO in QEMU, monitors serial for boot stages, checks for panic
- `release.yml` — tag-triggered GitHub Release with ISO + checksums
- `Dockerfile` — Fedora 42 build container with all tools
- `Makefile` — 15 unified targets (validate, build, test, release, docker, clean)
- `qemu-boot-test.sh` — standalone QEMU boot test
- `assemble-all.sh` — collects all packages into single install tree
- `.editorconfig` — code style enforcement

---

## How Everything Connects

```
User pushes code to GitHub
  → CI: validate.yml runs (shellcheck, flake8, ksvalidator)
  → CI: build-iso.yml runs
    → Fedora 42 container starts
    → livemedia-creator reads distro-live.ks
    → Kickstart installs packages from all profiles
    → Kickstart %post runs: configures system, creates services
    → Bootloader package files copied into image
    → ISO created with GRUB2 + dracut initramfs
  → CI: test-iso.yml runs
    → QEMU boots the ISO
    → Monitors serial for GRUB → kernel → systemd → desktop
    → Checks for kernel panic
  → ISO uploaded as artifact

User boots the ISO on real hardware
  → GRUB2 menu (with GPU-detected kernel params)
  → Live desktop (KDE Plasma, autologin as liveuser)
  → User clicks "Install KAAL OS"
  → Calamares launches:
    → profile-select module → user picks Gaming
    → de-select module → user picks KDE Plasma
    → bootloader-select module → user picks GRUB2
    → distro-context module → writes install-context.conf
    → 16 post-install scripts run in order:
      01: GPU detection + driver install
      02: DE installation (KDE + SDDM)
      03: Profile packages (Steam, Proton, MangoHud, etc.)
      04: Bootloader installation
      05: Auto-update service setup
      06: System tuning (sysctl, zram, I/O scheduler)
      07: Finalize + first-boot service
      08: Firmware (WiFi, Bluetooth, webcam)
      09: Network/WiFi (NetworkManager, DNS, firewall)
      10: Bluetooth (codecs, Blueman, udev)
      11: Audio (PipeWire low-latency, EasyEffects)
      12: Power (governor auto-switch, suspend/resume)
      13: Display (VRR, fractional scaling, multi-monitor)
      14: Input (touchpad, Wacom, controllers)
      15: USB (auto-mount, MTP, PTP, polkit)
      16: Fonts (CJK, Indic, emoji, fontconfig)
  → Reboot → first-boot service runs → desktop ready

Developer tags v0.1.0
  → release.yml creates GitHub Release with ISO + SHA256
```

---

## What's Still Remaining

1. **Distro name** — still `KAAL OS` placeholder everywhere
2. **Visual identity** — GRUB theme, Plymouth splash, Calamares branding, wallpaper, icons, SDDM/GDM theme
3. **RPM spec files** — package everything as installable `.rpm` files
4. **Integration testing** — test on real hardware with different GPU/CPU combos
5. **QML slides** — animated slides for Calamares installer
6. **Translations** — all strings are English-only

---

## Quick Reference

| What | Where |
|------|-------|
| Full spec | `docs/Distro_Specification.html` |
| Build the ISO | `packages/distro-iso-builder/build-iso.sh` |
| Bootloader config | `packages/distro-bootloader/etc/default/grub` |
| Calamares modules | `packages/distro-calamares/modules/` |
| Hardware scripts | `packages/distro-hardware/scripts/` |
| CI/CD workflows | `packages/distro-ci/.github/workflows/` |
| Unified build | `packages/distro-ci/Makefile` |
| Assemble everything | `packages/distro-ci/ci/assemble-all.sh` |

---

Generated: 2026-09-09
