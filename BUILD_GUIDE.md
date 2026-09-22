# KAAL OS — Build Guide
**Master v2 — merged, dependency-audited, build-ready**
Date: 2026-09-21

This archive contains the complete KAAL OS source tree: 186 files across 6 packages
(distro-bootloader, distro-iso-builder, distro-calamares, distro-hardware, kaal-spaces,
kaal-visual) plus CI. All fixes from the dependency audit, the Luanti update, and the
GRUB text fix are merged in. Nothing else needs applying — build from this tree.

---

## What was fixed in this merge (vs. the previous separate packages)

1. Kickstart: removed 9 build-breaking packages (syslinux ×2, python3-pyqt5,
   code, discord, signal-desktop, obsidian, onlyoffice, heroic-games-launcher);
   added 26 missing dependencies (python3-dbus/gobject/qt6, plymouth-plugin-script,
   cockpit, sysstat, iw, pciutils, usbutils, iproute-tc, wlr-randr, upower, etc.)
2. Kickstart: fixed an unterminated heredoc (CALEOF/CALeof case mismatch) that
   would have broken the whole %post section.
3. Kickstart: replaced the placeholder Calamares settings with the real module
   sequence (profile-select → de-select → space-select → …).
4. Kickstart: %post --nochroot now stages ALL packages (hardware scripts, Calamares
   modules, kaal-spaces, kaal-visual) — previously only bootloader/profiles were staged.
5. Calamares: scripts 08–16 (hardware) and 17 (spaces) are now actually chained in
   distro-post-install.conf — they were written but never wired.
6. Calamares: space-select module registered; distro-context writes KAAL_DEFAULT_SPACE.
7. Kaal Spaces: fake services removed, kwriteconfig6 detection, run_as_user fix, luanti pin.
8. Visual identity: doubled "KAAL OS" GRUB title fixed; background repositioned.
9. build-iso.sh stages all packages to /tmp/kaal-staging before livemedia-creator runs.

---

## Prerequisites (the build machine)

- A real Fedora 42 x86_64 machine (bare metal or VM) with:
  - ~15 GB free disk (builds use /var/tmp and ./results)
  - sudo access
  - internet connection (downloads ~2-4 GB of packages)

```bash
# 1. Install build tools
sudo dnf install -y lorax livemedia-creator pykickstart anaconda-tui \
    qemu-system-x86-core qemu-kvm libvirt

# 2. Unpack this archive
unzip KAAL_OS_MASTER_V6.zip
cd KAAL_OS_MASTER_V6/distro-master/packages/distro-iso-builder
```

---

## STEP A — Sanity test build first (15 minutes)

Build the minimal GNOME test image. This verifies the entire pipeline
(livemedia-creator, repo access, kickstart syntax, ISO assembly) before
you spend 45+ minutes on the full build.

```bash
sudo livemedia-creator \
    --ks=./distro-test-minimal.ks \
    --no-virt --iso-only \
    --tmp=/var/tmp/kaal-build \
    --resultdir=./results-test
```

**Expected result:** `results-test/KAAL-OS-test-*.iso` (~1.5-2 GB)

**If it fails:** read `/var/tmp/kaal-build/lmc-logs/` — the anaconda log names
the exact package or script that failed. Most first-build failures are package
names that differ in Fedora 42; fix the name in the .ks and re-run.

---

## STEP B — Boot-test the ISO in QEMU (5 minutes)

```bash
qemu-system-x86_64 -m 4096 -enable-kvm -cdrom \
    ./results-test/KAAL-OS-test-*.iso -boot d
```

Checklist (test image):
- [ ] GRUB menu shows "KAAL OS" entry
- [ ] Boots to a desktop (GNOME for the test image)
- [ ] Firefox is installed and opens
- [ ] Terminal: `python3 --version` shows 3.13
- [ ] Terminal: `node --version` shows Node 22

---

## STEP C — Full build (45-90 minutes)

```bash
cd distro-iso-builder
sudo ./build-iso.sh --name "KAAL OS" --resultdir ./results
```

`build-iso.sh` automatically stages all 6 packages into /tmp/kaal-staging before
invoking livemedia-creator with `distro-live.ks`.

**Full-image checklist after QEMU boot:**
- [ ] GRUB theme: gradient background, "KAAL OS" shown ONCE (no doubling)
- [ ] Plymouth splash renders (script-based kaal theme)
- [ ] Calamares installer launches from desktop icon
- [ ] Installer shows: Profile → Desktop → SPACE selection → Locale → Partition
- [ ] After install + reboot: `systemctl status kaal-spaced` is active
- [ ] `busctl --user status` / `gdbus call --dest org.kaal.Spaces ...` responds
- [ ] `kaal-space list` shows 4 spaces + templates
- [ ] `kaal-space switch gaming` → CPU governor becomes performance
- [ ] Luanti is in the application menu
- [ ] `systemctl status kaal-update-check.timer` is active

---

## STEP D — Real hardware

Flash the full ISO to USB and install on target hardware:
```bash
sudo dd if=./results/KAAL-OS-*.iso of=/dev/sdX bs=4M status=progress oflag=direct
```
(Replace /dev/sdX with your USB device — double-check with `lsblk` first.)

Hardware-specific checks:
- NVIDIA RTX 40-series: driver installs via akmod-nvidia (first boot takes ~3 min
  extra while the kernel module compiles); verify with `nvidia-smi`
- AMD GPUs: mesa/radv out of the box; verify with `vulkaninfo --summary`
- Wi-Fi, Bluetooth, audio (PipeWire) come up on first boot

---

## Troubleshooting the most likely first-build failures

| Symptom | Cause | Fix |
|---|---|---|
| "No package X available" in lmc log | Package renamed/not in F42 | Replace with correct name in .ks, re-run |
| Build dies in %post | Script bug in chroot | /var/tmp/kaal-build/install-root/root/distro-install.log |
| ISO boots to GRUB rescue | grub2-efi mismatch | Check `efibootmgr` present; use --make-iso default |
| Calamares missing modules | Staging missed a package | Verify /tmp/kaal-staging has all 7 dirs during build |
| kaal-spaced dead after install | python3-dbus/gobject missing | Both added in this merge; check `journalctl -u kaal-spaced` |
| Plymouth shows text fallback | plymouth-plugin-script missing | Added in this merge; check `plymouth show-splash` |

---

## Security (kaal-security package)

The master now ships with baseline OS hardening (`packages/kaal-security/`).
Post-install scripts **18–21** run at the end of the Calamares chain:

- **18-security-hardening.sh** — kernel sysctl hardening, SELinux switched to
  **enforcing** on the installed system (with first-boot relabel), SSH removed
  from the firewall's default zone, sshd disabled, auditd enabled with
  identity/sudoers/selinux watch rules, password quality policy
  (min 10 chars, 3 classes).
- **19-usbguard-setup.sh** — generates a machine-specific USBGuard policy:
  your own hardware + all HID always allowed, new storage/network devices
  require authorization via the usbguard-dbus applet.
- **20-antivirus-setup.sh** — ClamAV: signature updates always on, on-demand
  scanning ready (`kaal-antivirus scan <path>`), on-access scanning off by
  default (Security Space / `kaal-antivirus enable-on-access` turns it on).
- **21-vpn-setup.sh** — WireGuard + OpenVPN + openconnect preinstalled via
  NetworkManager. Provider apps are opt-in post-install:
  `sudo kaal-vpn install-proton [--cli]`, or import any provider's
  WireGuard/OpenVPN profile with `kaal-vpn import <file>`.

The **live ISO and the installed system both boot SELinux-enforcing**
(Fedora parity) — the ISO build relabels all custom files so enforcing mode
boots cleanly. Full policy: `docs/SECURITY.md`.

### Secure Boot — supported

The ISO ships Fedora's signed boot chain (`shim-x64` → `grub2-efi-x64` →
custom files relabeled — see below) directly from the Fedora repos — we theme
GRUB, we never replace its binary — so it **boots with UEFI Secure Boot
enabled**, with kernel lockdown engaging like Fedora Workstation. Verify with
the OVMF secure-boot QEMU test in `docs/SECURITY.md` (use `OVMF_CODE.secboot.fd`,
`-M q35,smm=on`). Only if the boot chain is ever replaced by a custom
unsigned GRUB would Secure Boot need to be disabled.

---

## Build for free on GitHub Actions (no machine needed)

You do not need any Fedora machine. Push this tree to a GitHub repository
and let GitHub's free runners build the ISO:

1. Create a **public** repository (free unlimited Actions minutes; a private
   repo also works but is capped at ~2000 free minutes/month).
2. Repo layout = this tree as-is: `packages/`, `docs/`, `BUILD_GUIDE.md` at
   the root, and the workflows copied to the repo root:
   ```
   cp -r packages/distro-ci/.github .
   git add . && git commit -m "KAAL OS master V6" && git push
   ```
3. GitHub → **Actions** tab → **Build ISO** → **Run workflow** → choose
   `both` (or `minimal-only` for the quick smoke test).
4. Wait for the run to finish (minimal ~20 min; full build 1–2 h) and
   download the ISO from the run's **Artifacts** panel. Artifacts are kept
   14 days — re-run the workflow any time for a fresh one.

The workflow stages all 7 packages exactly like a local `build-iso.sh`
run, so the CI ISO is the same ISO you would get on your own hardware.
If the build fails, open the run's log, copy the failing step output
(the last ~80 lines of build.log are printed on failure), and bring it
back for a fix. Boot testing still needs QEMU on any PC you own, or the
USB stick + your target machine — but building itself is fully free.

---

## Repo / naming notes

- Repos configured: Fedora Everything + RPM Fusion free/nonfree (in the .ks)
- Apps NOT in those repos (code, discord, signal, obsidian, onlyoffice, heroic)
  were removed from the kickstart. Install post-install via Flathub:
  `flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`
  then `flatpak install flathub <app-id>` (IDs listed in the dependency audit).
- The kaal-spaces RPM package doesn't exist yet; the file tree is staged directly.

## Package layout

```
distro-master/
├── packages/
│   ├── distro-bootloader/    GRUB2 config, GPU detect, snapshots, dracut
│   ├── distro-iso-builder/   kickstarts, profiles, scripts 01-07, build-iso.sh
│   ├── distro-calamares/     3 view modules + context job + settings + branding
│   ├── distro-hardware/      scripts 08-16 (firmware → fonts)
│   ├── kaal-spaces/          daemon, CLI, switcher, editor, 4+custom spaces
│   ├── kaal-visual/          GRUB/Plymouth/SDDM/GDM themes, wallpapers, icons
│   └── kaal-security/        hardening scripts 18-21, AV/VPN CLIs, configs
└── ci/                       assemble-all.sh, workflows, Dockerfile, qemu test
```
