# KAAL OS

A Fedora 44 based Linux distribution for gamers, developers and power users, built around **Kaal Spaces** — a runtime profile engine that reshapes the whole system around what you're doing, not the other way around.

One live USB. Six desktop environments (KDE, GNOME, Hyprland, Sway, XFCE, Cinnamon). A card-style installer that asks who you are and builds the machine you asked for.

> **Built openly with AI.** KAAL OS is an experiment in one designer directing AI tooling (Sarvam Indus Cowork) to build and maintain a complete Linux distribution — including its CI pipeline. The commit history is the case study.

---

## Current status (honest)

| Area | State |
|------|-------|
| Fedora 44 base (rebased from EOL Fedora 42) | ✅ Done |
| Minimal test ISO — builds green in CI | ✅ Done (runs on every push, ~15 min) |
| Minimal test ISO — bootable artifact | ✅ [Download](#try-the-test-iso) (GNOME + Firefox, 2.1 GB) |
| Full live ISO (all 7 packages, 6 DEs) | 🔨 First real build in progress |
| Validate workflow | ⚠️ 11 pre-existing lint findings (non-blocking) |
| RPM packaging | 🚧 Packages are staged via kickstart, not built as RPMs yet |
| License | ✅ GPLv3 |

The minimal test ISO proves the whole chain end to end: repositories → kickstart → anaconda install → squashfs → EFI/BIOS bootable ISO — all in GitHub Actions, no build machine needed.

---

## Try the test ISO

1. Go to the **Actions** tab → **Build ISO** → the most recent successful run → scroll down to **Artifacts** → download `kaal-minimal-test-iso` (a zip containing `boot.iso`, ~2.1 GB).
2. Boot it in VirtualBox or QEMU:
   ```sh
   qemu-system-x86_64 -m 4096 -enable-kvm -cdrom boot.iso
   ```
3. You should land on a GNOME desktop, auto-logged in as `liveuser`. Firefox is installed. Nothing is persistent — it's a live image.

This is the **minimal smoke build** (GNOME + Firefox only). The full live ISO with all profiles, all desktops and the Calamares installer is the one under construction — `distro-live.ks` + all 7 packages.

---

## What's in the repo

Seven packages make up the distribution:

| Package | What it does |
|---------|--------------|
| `distro-bootloader` | GRUB2 + systemd-boot config with GPU-aware kernel params, snapshot boot entries, safe-mode fallback |
| `distro-iso-builder` | The kickstarts, `build-iso.sh`, profile package lists, post-install scripts 01–07 |
| `distro-calamares` | Card-style Calamares modules: profile select, DE select, bootloader select, install context |
| `distro-hardware` | Post-install scripts 08–16: firmware, network, Bluetooth, PipeWire audio, power, display, input, USB, fonts |
| `kaal-spaces` | The Kaal Spaces engine itself — daemons, panels, hooks, script 17 |
| `kaal-visual` | Visual identity: GRUB/Plymouth theme, wallpapers, install scripts |
| `kaal-security` | Scripts 18–21: USBGuard, audit, ClamAV antivirus, WireGuard/OpenVPN |
| `distro-ci` | Makefile, Dockerfile, QEMU boot test, assemble script |

Full blueprint: `docs/Distro_Specification.html` (15 sections, opens in a browser).
Build instructions: `BUILD_GUIDE.md`.

## How a build works

```
push to main
  → Build ISO workflow (GitHub Actions)
    → smoke job: minimal kickstart in a Fedora 44 container
      → livemedia-creator → anaconda → squashfs → boot.iso
    → full job: stage all 7 packages → distro-live.ks → full ISO + SHA256
  → Test ISO workflow boots the result in QEMU (planned)
  → tag v* → Release workflow publishes the ISO
```

Everything runs on free GitHub-hosted runners — no build hardware required.

## Roadmap

1. ~~Fedora 44 rebase~~ ✅
2. ~~Minimal test ISO green~~ ✅
3. Full live ISO green ← **you are here**
4. Test ISO (QEMU boot gate) green
5. First tagged release (`v0.0.1`)
6. RPM packaging of the 7 packages
7. Visual identity pass (GRUB/Plymouth/SDDM themes, wallpapers)
8. Translations (starting with Hindi + Marathi)

## Get involved

KAAL OS is looking for two kinds of people:

- **Testers** — boot the ISOs (VM or spare hardware), especially NVIDIA / AMD rigs, laptops, and unusual Wi-Fi/Bluetooth combos. Every issue filed with hardware details is gold. Open an issue with the `test-report` label.
- **UI/UX co-designers** — the installer is card-style, the Spaces concept needs a real design partner, and the visual identity is unclaimed territory. This is a rare chance to shape a distro's whole look and feel from zero.

No contribution too small — even "it booted on my machine, here's a screenshot" helps.

## Quick reference

| What | Where |
|------|-------|
| Full spec | `docs/Distro_Specification.html` |
| Build the ISO | `packages/distro-iso-builder/build-iso.sh` |
| Smoke kickstart | `packages/distro-iso-builder/distro-test-minimal.ks` |
| Full kickstart | `packages/distro-iso-builder/distro-live.ks` |
| CI workflows | `.github/workflows/` |
| Calamares modules | `packages/distro-calamares/modules/` |
| Hardware scripts | `packages/distro-hardware/scripts/` |
| Spaces engine | `packages/kaal-spaces/` |
| Unified build | `packages/distro-ci/Makefile` |
