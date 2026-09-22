# =============================================================================
# distro-test-minimal.ks — Minimal Test Kickstart for Pipeline Verification
# =============================================================================
# A tiny kickstart that boots to a basic GNOME desktop. Use this FIRST
# to verify your build pipeline works before trying the full distro.
#
# Build:
#   sudo livemedia-creator --ks distro-test-minimal.ks --no-virt \
#     --image-only --tmp /var/tmp/test-build \
#     --resultdir ./test-results --releasever 42 \
#     --title "Test Build" --make-iso --compress xz
#
# This builds in ~15 minutes (vs ~45 for the full distro) and produces
# a bootable ISO with just GNOME + Firefox. If this boots in QEMU/VirtualBox,
# your pipeline works and you can move to the full distro-live.ks.
# =============================================================================

lang en_US.UTF-8
keyboard us
timezone Asia/Kolkata --utc
rootpw --lock
selinux --permissive
firewall --enabled --ssh
services --enabled=NetworkManager
network --bootproto=dhcp --activate

# ---- Disk layout (lmc --no-virt installs into a sparse disk image) ----
bootloader --timeout=1
clearpart --all --initlabel
part / --size 6144 --fstype ext4

# ---- Repositories ----
url --url="https://download.fedoraproject.org/pub/fedora/linux/releases/42/Everything/x86_64/os/"
repo --name=fedora --baseurl=https://download.fedoraproject.org/pub/fedora/linux/releases/$releasever/Everything/$basearch/os/ --cost=1
repo --name=updates --baseurl=https://download.fedoraproject.org/pub/fedora/linux/updates/$releasever/Everything/$basearch/ --cost=1

# ---- Minimal Package Set ----
%packages --exclude-weakdeps
@core
@standard
@hardware-support
@base-x
@fonts
@gnome-desktop
@wayland
kernel
kernel-modules
grub2
grub2-efi-x64
grub2-tools
shim-x64
dracut
dracut-live
NetworkManager
NetworkManager-wifi
pipewire
pipewire-pulseaudio
wireplumber
firefox
btrfs-progs
ntfs-3g
dosfstools
flatpak
fwupd
livecd-tools
xorriso
isomd5sum
-sendmail
-postfix
-nano
%end

# ---- Minimal Post-Install ----
%post --erroronfail
echo "distro-test" > /etc/hostname

# Basic os-release
cat > /etc/os-release << 'EOF'
NAME="KAAL OS Test"
ID=distro-test
ID_LIKE=fedora
VERSION="0.1-test"
PRETTY_NAME="KAAL OS Test Build (Minimal)"
ANSI_COLOR="0;36"
HOME_URL="https://distro.example.com"
EOF

# Enable services
systemctl enable NetworkManager gdm pipewire wireplumber 2>/dev/null || true

# Live user
useradd -m -G wheel liveuser 2>/dev/null || true
passwd -d liveuser 2>/dev/null || true

# Autologin for live image
mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf << 'EOF'
[daemon]
WaylandEnable=true
AutomaticLoginEnable=true
AutomaticLogin=liveuser
EOF

# Clean up
dnf clean all
rm -rf /var/cache/dnf/* /var/tmp/* /tmp/*
%end
