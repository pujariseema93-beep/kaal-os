# KAAL Security — OS-level hardening for KAAL OS

The `kaal-security` package provides baseline operating-system hardening for
the **installed system** (Calamares post-install chain, scripts 18–19). It is
deliberately separate from the *Security Space* (a user profile for security
researchers with pentest tools) — this package hardens the OS itself.

## What it does

| Area | Default on installed system | Live ISO |
|---|---|---|
| SELinux | **enforcing** (Fedora parity, live and installed) | enforcing |
| Firewall | firewalld enabled, SSH **closed** | same |
| sshd | installed but **disabled** (Security Space enables it) | same |
| Kernel sysctls | hardening profile (`/etc/sysctl.d/70-kaal-security.conf`) | same |
| USB devices | USBGuard with HID + install-time allowlist | same |
| Audit | auditd with identity/sudoers/selinux watch rules | same |
| Passwords | pwquality: min 10 chars, 3 classes | same |
| Antivirus | ClamAV: updates on, on-demand ready, on-access opt-in | same |
| VPN | WireGuard + OpenVPN + openconnect via NetworkManager | same |

## Layout

```
config/sysctl-70-kaal-security.conf   → /etc/sysctl.d/70-kaal-security.conf
config/audit-70-kaal.rules            → /etc/audit/rules.d/70-kaal.rules
config/pwquality-kaal.conf            → /etc/security/pwquality.conf.d/kaal.conf
scripts/18-security-hardening.sh      → /usr/libexec/distro-installer/
scripts/19-usbguard-setup.sh         → /usr/libexec/distro-installer/
scripts/20-antivirus-setup.sh        → /usr/libexec/distro-installer/
scripts/21-vpn-setup.sh               → /usr/libexec/distro-installer/
usr/bin/kaal-antivirus                → /usr/bin/ (user CLI)
usr/bin/kaal-vpn                      → /usr/bin/ (user CLI)
```

During ISO build the tree is staged to `/usr/share/kaal-security/`; the four
scripts run in the Calamares chroot after `unpackfs`, copying configs into
place, enabling services and installing the user CLIs.

## Design decisions

- **Fedora parity.** SELinux is enforcing in the live image AND the installed
  system, exactly like Fedora Workstation. The ISO build relabels every
  custom file (`restorecon -R /etc /usr`) so enforcing boots cleanly;
  script 18 pins the config and schedules a relabel for install-time files.
- **SSH closed by default.** sshd is installed (the Security Space needs it)
  but neither enabled nor opened in the firewall. Switching to the Security
  Space starts it and opens the port.
- **User namespaces NOT restricted.** Flatpak and Distrobox depend on them.
- **ptrace_scope = 1**, not 2 — gdb still attaches to children, so the
  Development Space keeps working.
- **Spaces never override hardening.** A Space may change governors, services
  and audio; it cannot change SELinux mode, firewall base policy or audit
  rules.
- **VPN provider apps are opt-in.** Protocols are preinstalled; `sudo
  kaal-vpn install-proton` adds Proton's official repo to the user's system
  only. Third-party signing keys are never baked into the ISO.

## Rolling back

```
sudo rm /etc/sysctl.d/70-kaal-security.conf /etc/audit/rules.d/70-kaal.rules
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
sudo systemctl disable --now usbguard auditd
```

See `docs/SECURITY.md` in the master tree for the full policy.
