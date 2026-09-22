# KAAL OS Security Policy

Status: v1 — baseline hardening (master V3). This document defines what
"secure by default" means for KAAL OS and what is deliberately left open.

## Scope and layers

| Layer | What | Where |
|---|---|---|
| Live ISO | enforcing SELinux (Fedora parity), firewall on, no SSH | `distro-live.ks` |
| Installed system | enforcing SELinux, hardened kernel, auditd, USBGuard | `kaal-security` scripts 18-19 |
| User profiles | Security Space (pentest tools, sshd, on-access AV) | `kaal-spaces` |
| Antivirus | ClamAV — updates on, on-demand always, on-access opt-in | `kaal-security` script 20 |
| VPN | WireGuard + OpenVPN + openconnect preinstalled; provider apps opt-in | `kaal-security` script 21 |
| CI | boot test only (no security scanning yet) | `distro-ci` |

The **Security Space** is a workspace for security researchers. It is NOT
OS hardening — it actually *widens* the attack surface on purpose (sshd,
packet capture, VMs). The `kaal-security` package is the opposite direction
and both can coexist: the Space toggles runtime services, hardening owns
system policy.

## Hardening applied on the installed system (script 18)

- Kernel: `kptr_restrict=1`, `dmesg_restrict=1`, `ptrace_scope=1`,
  unprivileged BPF disabled, BPF JIT hardened, protected links/symlinks,
  ICMP/redirect hardening for IPv4+IPv6
  (`/etc/sysctl.d/70-kaal-security.conf`)
- SELinux: enforcing + `/.autorelabel` on first boot of the install
- Firewall: ssh removed from the default zone; firewalld enabled
- sshd: installed but disabled (Security Space enables it on demand)
- auditd: watch rules on identity files, sudoers, polkit, SELinux config,
  login records, USBGuard policy, audit config itself
- Passwords: pwquality minlen=10, minclass=3, dictcheck, usercheck

## USB device control (script 19)

USBGuard with a policy generated per machine at install time:

- Devices present during install are permanently allowed
- All HID (keyboards, mice, tablets) always allowed on any port
- Unknown devices (storage, network, etc.) are blocked and surfaced as an
  authorization prompt via `usbguard-dbus`

Rollback: `sudo systemctl disable --now usbguard`.

## Deliberately NOT hardened (and why)

- **User namespaces unrestricted** — Flatpak and Distrobox depend on them
- **ptrace_scope=1, not 2** — gdb on own children must keep working (Development Space)
- **No execve audit logging** — too noisy for a desktop
- **On-access antivirus off by default** — every file open would pay the
  ClamAV tax; opt-in via `kaal-antivirus enable-on-access` or the Security
  Space
- **Live ISO permissive** — FIXED in V5: the live image now boots enforcing
  (Fedora parity); the build relabels every custom file with `restorecon`
  so enforcing boots cleanly
- **No fapolicyd / OpenSCAP profile** — future work; see below

## Spaces and security — non-negotiable rule

A Space may change: CPU/GPU governors, audio quantum, compositor, services,
pinned apps, wallpaper, environment variables.
A Space may NEVER change: SELinux mode, firewall base policy, audit rules,
USBGuard policy, password policy. The apply-space hooks are audited against
this rule; any hook that violates it is a bug.

## Secure Boot (supported since V5)

The ISO boots **with Secure Boot enabled**: it ships Fedora's signed
`shim-x64` → `grub2-efi-x64` → Fedora kernel chain straight from the Fedora
repos (all Microsoft/Fedora-signed binaries — we only theme GRUB, we never
replace its binary). Kernel lockdown therefore engages automatically, the
same as on Fedora Workstation.

Verify in QEMU with an OVMF secure-boot firmware:

```
sudo dnf install -y edk2-ovmf
cp /usr/share/edk2/ovmf/OVMF_VARS.fd .
qemu-system-x86_64 -M q35,smm=on -m 4096 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.secboot.fd \
  -drive if=pflash,format=raw,file=OVMF_VARS.fd \
  -cdrom KAAL_OS-live-*.iso -boot d
```

If it ever fails: check that `shim-x64` and `grub2-efi-x64` in the kickstart
were not replaced by custom-built (unsigned) binaries. Building and
enrolling our own keys (MOK) remains optional post-1.0 work — it is not
needed for Secure Boot to work.

## Fedora parity — where KAAL OS matches and where it differs

Target: **Fedora Workstation baseline**. Matching: SELinux enforcing
(live + installed, with build-time relabel), firewalld on with no services
exposed, sshd off, signed packages only (`gpgcheck=1` +
`localpkg_gpgcheck=1`), Secure Boot chain, LUKS offered at install, fwupd
firmware updates, dnf notify-on-update behavior, crypto-policies DEFAULT.
Beyond Fedora: kernel sysctl hardening, auditd watch rules, USBGuard,
password quality. Differing (accepted trade-offs, be aware):

- RPM Fusion free/nonfree repos enabled (NVIDIA, extra codecs) — wider
  package surface than vanilla Fedora
- cockpit + libvirt-daemon installed (Space-controlled, not enabled by
  default)
- Custom Calamares modules and kaal-spaces daemon are additional code
  Fedora does not ship — audited, but new code

## Antivirus (ClamAV)

`clamav`, `clamav-data`, `clamav-freshclam` and `clamd` ship in the image;
script 20 configures them:

- **Signature updates always on** (`clamav-freshclam.service`) — cheap, no
  desktop impact
- **On-demand scanning always available**: `kaal-antivirus scan ~/Downloads`
  (uses clamd when running, clamscan otherwise)
- **On-access scanning OFF by default** — it taxes every file open, the wrong
  trade for a gaming distro. Enable per-machine with
  `sudo kaal-antivirus enable-on-access`, or automatically via the Security
  Space; the Gaming Space force-disables it

Philosophy: Linux desktop malware is rare; SELinux, USBGuard and the hardened
kernel (scripts 18–19) are the primary defenses. ClamAV exists mainly to scan
files shared with Windows machines (dual-boot, email, downloads) — its
definitions are Windows-centric, which is exactly the threat users forward.

## VPN

The **open protocol stack is preinstalled** — no third-party keys baked into
the ISO: WireGuard (kernel-native, `wireguard-tools`), OpenVPN
(+ NetworkManager plugin), and openconnect (Cisco/AnyConnect-compatible).

- `kaal-vpn import <file.conf|.ovpn>` — imports WireGuard or OpenVPN profiles
  into NetworkManager (e.g. Proton's downloadable WireGuard configs — works
  with any provider, zero extra software)
- `sudo kaal-vpn install-proton [--cli]` — opt-in: adds Proton's official
  Fedora repository to THIS system and installs the Proton VPN app
  (`proton-vpn-gnome-desktop` or `proton-vpn-cli`)
- `sudo kaal-vpn remove-proton` — full removal, repo disabled

Why opt-in for provider apps: a distro image should not carry third-party
signing keys it cannot revoke on the user's behalf, and Proton's GUI app
officially targets GNOME (on other DEs we recommend the CLI or profile
import). The protocols are open and universal; the trust decision stays
with the user.

## Automatic updates

Default is check-and-notify on every boot (existing behavior). Automatic
*installation* of security updates is not enabled by default — gaming
kernels should not change mid-session. Users can opt in:
`sudo dnf install dnf5-automatic && sudo systemctl enable --now dnf5-automatic.timer`.

## Incident notes for testers

- SELinux denials on first boot: `ausearch -m avc -ts recent`,
  fix with `setsebool`/chcon, or `sudo touch /.autorelabel && reboot`
  if a mislabel is suspected. setroubleshoot-server ships on the image to
  explain denials in the GUI.
- USB device not working (was plugged in during install but blocked):
  `sudo usbguard list-devices` / `sudo usbguard allow-device <id>`
- Everything off: see "Rolling back" in `packages/kaal-security/README.md`.
