# =============================================================================
# distro-live.ks — KAAL OS Live ISO Kickstart File
# =============================================================================
# This kickstart file defines the entire live ISO image for KAAL OS.
# It is consumed by livemedia-creator (lorax) to build a bootable ISO.
#
# Build command:
#   sudo livemedia-creator --ks distro-live.ks \
#     --no-virt --image-only --tmp /var/tmp/distro-build \
#     --resultdir /var/tmp/distro-results --iso-label KAAL OS \
#     --releasever 42 --title "KAAL OS Live" --macboot
#
# The kickstart has three phases:
#   1. %package — defines which RPM packages to install
#   2. %post — runs scripts inside the chroot (customizes the image)
#   3. %end — finalizes the image
#
# This builds the LIVE image (bootable USB/DVD). The Calamares installer
# inside the live image handles permanent installation to disk.
# =============================================================================

# ---- Live image definition ----
# livemedia-creator handles disk setup; we just define content
text

# ---- Language and Keyboard ----
lang en_US.UTF-8
keyboard us

# ---- Timezone ----
timezone Asia/Kolkata --utc

# ---- Root password (disabled for live image) ----
rootpw --lock

# ---- Live image user ----
# The live user is created by the live image tools, but we define it here
user --name=liveuser --password="" --groups=wheel --gecos="KAAL OS Live User"

# ---- SELinux ----
# Fedora parity: enforcing everywhere — live AND installed. All custom files
# laid down by the build are relabeled in %post (restorecon) so enforcing
# mode boots cleanly; script 18 keeps the installed system enforcing.
selinux --enforcing

# ---- Firewall ----
# SSH is closed by default; the Security Space opens it on demand.
firewall --enabled

# ---- Services to enable/disable ----
# sshd is installed but NOT enabled (Security Space enables it when needed)
services --enabled=NetworkManager,bluetooth,cups,avahi-daemon
services --disabled=

# =============================================================================
# Repositories
# =============================================================================
# Fedora base repos + RPM Fusion for proprietary drivers and codecs
# =============================================================================

# ---- Fedora Base ----
repo --name=fedora --baseurl=https://download.fedoraproject.org/pub/fedora/linux/releases/$releasever/Everything/$basearch/os/ --cost=1
repo --name=updates --baseurl=https://download.fedoraproject.org/pub/fedora/linux/updates/$releasever/Everything/$basearch/ --cost=1

# ---- RPM Fusion Free (open-source software with patent issues) ----
repo --name=rpmfusion-free --baseurl=https://download1.rpmfusion.org/free/fedora/releases/$releasever/Everything/$basearch/os/ --cost=2
repo --name=rpmfusion-free-updates --baseurl=https://download1.rpmfusion.org/free/fedora/updates/$releasever/Everything/$basearch/ --cost=2

# ---- RPM Fusion Nonfree (NVIDIA driver, proprietary codecs) ----
repo --name=rpmfusion-nonfree --baseurl=https://download1.rpmfusion.org/nonfree/fedora/releases/$releasever/Everything/$basearch/os/ --cost=3
repo --name=rpmfusion-nonfree-updates --baseurl=https://download1.rpmfusion.org/nonfree/fedora/updates/$releasever/Everything/$basearch/ --cost=3

# ---- Flathub (Flatpak repository) ----
# Configured post-install via flatpak remote-add

# =============================================================================
# Package Selection
# =============================================================================
# Base system + all profiles. The live image includes everything so the
# user can try any profile. The installer (Calamares) will prune packages
# based on the selected profile during permanent installation.
# =============================================================================

%packages --exclude-weakdeps

# ---- Base System ----
@core
@standard
@hardware-support
@base-x
@fonts
@input-methods
@multimedia
@networkmanager-submodules
@printing
@workstation-product

# ---- Kernel ----
kernel
kernel-modules
kernel-modules-extra
akmod-nvidia          # NVIDIA driver (built for current kernel)
akmod-nvidia-open     # NVIDIA open kernel modules (Turing+)

# ---- Filesystem Support ----
btrfs-progs
ntfs-3g
ntfsprogs
exfatprogs
f2fs-tools
xfsprogs
dosfstools

# ---- Bootloader (installed via bootloader package, but include here) ----
grub2
grub2-efi-x64
grub2-tools
grub2-tools-extra
shim-x64
efibootmgr
mokutil
systemd-boot           # Alternative bootloader
dracut
dracut-tools

# ---- Display Server & Audio ----
@wayland
xorg-x11-server-Xorg
xorg-x11-drv-libinput
pipewire
pipewire-alsa
pipewire-pulseaudio
pipewire-jack-audio-connection-kit
wireplumber
pipewire-utils

# ---- Desktop Environments (all included for live image) ----
@kde-desktop
@gnome-desktop
@xfce-desktop
@cinnamon-desktop
# Hyprland and Sway installed via explicit packages below

hyprland              # Wayland tiling compositor
sway                  # i3-compatible Wayland compositor
waybar                # Status bar for Wayland
swaylock              # Screen locker for Sway
swayidle              # Idle manager for Sway
wofi                  # Wayland launcher
foot                  # Wayland terminal
wl-clipboard          # Wayland clipboard utilities

# ---- Display Managers ----
sddm                   # KDE login manager
gdm                    # GNOME login manager
lightdm                # XFCE/Cinnamon login manager

# ---- Gaming Stack ----
steam
protonup-qt
lutris
# REMOVED (dep audit): heroic-games-launcher
bottles
gamemode
mangohud
gamescope
vkbasalt
corectrl
obs-studio
gpu-screen-recorder
retroarch
dolphin-emu
rpcs3
ppsspp
pcsx2
ryujinx
# ---- Native Linux games (pre-installed) ----
luanti
godot
wine
wine-mono
wine-gecko
winetricks
protontricks
dxvk
vkd3d
vkd3d-proton
mesa-vulkan-drivers
vulkan-tools
vulkan-loader
vulkan-validation-layers

# ---- NVIDIA Driver Stack ----
nvidia-settings
nvidia-persistenced
cuda-toolkit          # CUDA for compute
libva-vdpau-driver    # VAAPI/VDPAU bridge
vdpauinfo

# ---- AMD GPU Tools ----
libdrm
mesa-dri-drivers
mesa-va-drivers
mesa-vdpau-drivers
vulkan-radeon
clinfo
rocminfo              # ROCm for GPU compute (optional)

# ---- Developer Tools ----
@development-tools
@container-management
python3
python3-pip
python3-virtualenv
nodejs
npm
rust
cargo
go
java-21-openjdk
java-21-openjdk-devel
gcc
gcc-c++
clang
clang-devel
cmake
make
ninja-build
git
git-core
gh                    # GitHub CLI
glab                  # GitLab CLI
neovim
vim
emacs
helix
# REMOVED (dep audit): code
podman
podman-compose
docker
docker-compose
distrobox
toolbx
buildah
skopeo
tmux
zellij
htop
btop
lazygit
lazydocker
fzf
ripgrep
fd-find
bat
eza
delta
starship
zsh
fish
python3-rich
python3-textual
jq
yq
httpie
curl
wget
openssl
gnupg2
openssh-server
openssh-clients
rsync
unzip
zip
tar
p7zip
p7zip-plugins
shellcheck
pre-commit
act                   # Run GitHub Actions locally

# ---- Daily Life Applications ----
firefox
thunderbird
libreoffice
# REMOVED (dep audit): onlyoffice
spotify-client
# REMOVED (dep audit): discord
telegram-desktop
# REMOVED (dep audit): signal-desktop
vlc
mpv
celluloid
easyeffects
gimp
inkscape
blender
krita
audacity
kdenlive
flameshot
keepassxc
gnome-boxes
virt-manager
timeshift
bauh
gnome-software
discover
flatpak
appstream
gnome-tweaks
kvantum
ffmpeg
ffmpeg-libs
gstreamer1
gstreamer1-plugins-base
gstreamer1-plugins-good
gstreamer1-plugins-bad-free
gstreamer1-plugins-ugly-free
gstreamer1-vaapi
gstreamer1-libav
pipewire-ffmpeg
codecs               # Meta-package for all codecs

# ---- System Tools ----
NetworkManager
NetworkManager-wifi
NetworkManager-bluetooth
blueman
bluez
bluez-tools
cups
cups-filters
system-config-printer
sane-backends
sane-frontends
xsane
simple-scan
fwupd
fwupd-efi
power-profiles-daemon
thermald
tlp                  # Power management (alternative)
smartmontools
gdisk
parted
gparted
ntfs-3g
policycoreutils
setools-console
restorecond
man-pages
man-db
bash-completion
zsh-completions
fish-completions
ntfs-3g-system-compression
fuse-libs
fuse-exfat
udisks2
gvfs
gvfs-mtp
gvfs-gphoto2
gvfs-smb
gvfs-afc

# ---- Live Image Tools ----
livecd-tools
anaconda              # Fedora installer (fallback if Calamares not used)
calamares             # Primary installer
calamares-config       # Calamares configuration
# REMOVED (dep audit): python3-pyqt5

# ---- Bootloader Package (our custom package) ----
# This would be our distro-bootloader RPM. For now, include the files
# manually via %post --nochroot copy.
# distro-bootloader      # Our custom bootloader package

# ---- Kernel modules for live USB ----
livecd-tools
# REMOVED (dep audit): syslinux
# REMOVED (dep audit): syslinux-extlinux
xorriso
isomd5sum

# ---- Exclude packages we don't want ----
-sendmail
-postfix
-nano
-nano-default-editor
-fedora-release
-fedora-release-identity
-fedora-release-common
-fedora-release-workstation
-fedora-logos
-fedora-backgrounds
-centos-logos
-redhat-logos


# ---- KAAL OS dependency-audit fixes (build-critical) ----
python3-qt5               # correct Fedora name (was python3-pyqt5)
python3-dbus               # kaal-spaced daemon
python3-gobject            # kaal-spaced + kaal-space-auto (gi/GLib)
python3-qt6                # space switcher + editor GUIs
dbus-tools                 # kaal-space CLI (dbus-send)
plymouth-plugin-script     # KAAL Plymouth theme (script engine)
iw                         # WiFi scanning
usbutils                   # lsusb
pciutils                   # lspci / GPU detection
iproute-tc                 # tc (gaming network QoS)
wlr-randr                  # Wayland display config
xorg-x11-server-utils      # xrandr
upower                     # power state
brightnessctl              # backlight
light                      # backlight fallback
librsvg2-tools             # rsvg-convert (theme installers)
ImageMagick                # SVG fallback conversion
libinput-utils             # input configuration
fontconfig                 # fc-cache
cockpit                    # power/dev spaces enable cockpit.socket
libvirt-daemon             # dev space enables libvirtd
libvirt-daemon-kvm
sysstat                    # power space metrics
xorg-x11-drv-nvidia        # nvidia-smi userspace
iotop                      # power space pinned app

# ---- KAAL OS security (kaal-security package) ----
usbguard                   # USB device control
usbguard-dbus              # USB authorization applet (D-Bus)
audit                      # auditd + watch rules
setroubleshoot-server      # SELinux denial diagnostics

# ---- KAAL OS antivirus + VPN (kaal-security scripts 20-21) ----
clamav                     # ClamAV engine + tools (clamscan, clamonacc)
clamav-data                # virus signature database
clamav-freshclam           # signature auto-updater
clamd                      # antivirus daemon (on-demand/on-access backend)
wireguard-tools            # WireGuard (wg, wg-quick)
openvpn                    # OpenVPN client
NetworkManager-openvpn     # NM integration: OpenVPN
NetworkManager-openvpn-gnome  # VPN auth dialogs (works on all DEs)
openconnect                # Cisco/AnyConnect-compatible client
NetworkManager-openconnect    # NM integration: openconnect
NetworkManager-openconnect-gnome  # auth dialogs

%end

# =============================================================================
# Post-Install Scripts
# =============================================================================
# These run inside the chroot after packages are installed.
# =============================================================================

# -----------------------------------------------------------------------------
# %post — Main customization (runs inside chroot)
# -----------------------------------------------------------------------------
%post --erroronfail --log=/root/distro-install.log

# ==== Set hostname ====
echo "kaal-live" > /etc/hostname

# ==== Create distro identity ====
# Replace placeholder distro name throughout the system
DISTRO_NAME="KAAL OS"
DISTRO_LOWERCASE="kaal"

# ==== Configure DNF ====
cat > /etc/dnf/dnf.conf << 'DNFEOF'
[main]
gpgcheck=1
localpkg_gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=False
skip_if_unavailable=True
max_parallel_downloads=10
fastestmirror=True
metadata_timer_sync=True
dnf5_commands=autoremove,check-update,distrosync,downgrade,groupinfo,groupinstall,grouplist,groupremove,groupupgrade,history,info,install,list,makecache,mark,reinstall,remove,repoquery,search,updateinfo,upgrade,upgrade-minimal
DNFEOF

# ==== Enable RPM Fusion repos ====
dnf config-manager --set-enabled rpmfusion-free rpmfusion-free-updates rpmfusion-nonfree rpmfusion-nonfree-updates 2>/dev/null || true

# ==== Install NVIDIA driver (if NVIDIA GPU detected) ====
# During live image build, we include the akmod packages which will be
# compiled on first boot. For the live image, we pre-build them.
if lspci | grep -qi 'NVIDIA'; then
    echo "NVIDIA GPU detected — pre-building driver modules..."
    akmods --force 2>/dev/null || true
    # Enable nvidia-persistenced
    systemctl enable nvidia-persistenced 2>/dev/null || true
fi

# ==== Configure Flatpak ====
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

# ==== Create distro directories ====
mkdir -p /etc/distro-bootloader
echo "grub2" > /etc/distro-bootloader/active

# ==== Install bootloader config files ====
# These would come from the distro-bootloader RPM. For the live image,
# we copy them from the build directory.
# (In production, these are installed via the distro-bootloader package)
if [ -d /usr/share/distro-bootloader ]; then
    echo "Bootloader package already installed"
else
    echo "Bootloader package not found — configs will be added by installer"
fi

# ==== Configure GRUB ====
# Source the main grub config if our custom one exists
if [ -f /etc/default/grub ]; then
    # Make GRUB scripts executable
    chmod +x /etc/grub.d/0*-distro* /etc/grub.d/2*-distro* 2>/dev/null || true
fi

# ==== Create auto-update systemd service ====
mkdir -p /etc/systemd/system

cat > /etc/systemd/system/kaal-update-check.service << 'SVCEOF'
[Unit]
Description=KAAL OS Boot Update Check
After=network-online.target graphical-session.target
Wants=network-online.target
ConditionPathExists=!/run/distro-update-check.done

[Service]
Type=oneshot
ExecStart=/usr/libexec/distro-bootloader/distro-update-check
ExecStartPost=/bin/touch /run/distro-update-check.done
RemainAfterExit=yes
# Don't run if metered connection
ConditionPathExists=!/run/NetworkManager/metered

[Install]
WantedBy=graphical-session.target
SVCEOF

cat > /etc/systemd/system/kaal-update-check.timer << 'TMREOF'
[Unit]
Description=KAAL OS Boot Update Check Timer

[Timer]
OnBootSec=30sec
OnUnitActiveSec=4h
Persistent=true

[Install]
WantedBy=timers.target
TMREOF

# ==== Create the update check script ====
mkdir -p /usr/libexec/distro-bootloader

cat > /usr/libexec/distro-bootloader/distro-update-check << 'UPDEOF'
#!/bin/bash
# KAAL OS Boot Update Check Script
# Checks for updates on every boot and notifies the user

set -euo pipefail

LOG_FILE="/var/log/distro-update-check.log"
NOTIFY_SENT=false

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "Starting boot update check..."

# Check DNF updates
log "Checking DNF updates..."
DNF_UPDATES=$(dnf5 check-update --quiet 2>/dev/null | grep -c '\.rpm' || echo "0")

# Check Flatpak updates
log "Checking Flatpak updates..."
FLATPAK_UPDATES=$(flatpak update --no-deploy --no-interaction 2>/dev/null | grep -c '^\s' || echo "0")

# Check firmware updates
log "Checking firmware updates..."
fwupdmgr refresh --quiet 2>/dev/null || true
FW_UPDATES=$(fwupdmgr get-updates --quiet 2>/dev/null | grep -c 'Update available' || echo "0")

TOTAL=$((DNF_UPDATES + FLATPAK_UPDATES + FW_UPDATES))
log "Found: DNF=$DNF_UPDATES Flatpak=$FLATPAK_UPDATES Firmware=$FW_UPDATES Total=$TOTAL"

if [ "$TOTAL" -gt 0 ]; then
    # Download updates in background
    log "Downloading DNF updates..."
    dnf5 download --allowerasing --quiet $(dnf5 check-update --quiet 2>/dev/null | awk '{print $1}' | head -50) 2>/dev/null || true

    # Send desktop notification
    if command -v notify-send >/dev/null 2>&1; then
        export DISPLAY=:0
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u liveuser 2>/dev/null || echo 1000)/bus"
        notify-send -u normal -a "KAAL OS Update Checker" \
            "$TOTAL updates available" \
            "DNF: $DNF_UPDATES | Flatpak: $FLATPAK_UPDATES | Firmware: $FW_UPDATES\nClick to install or run: sudo dnf5 upgrade" \
            2>/dev/null || true
    fi
    log "Notification sent for $TOTAL updates"
else
    log "System is up to date"
fi

# Take a pre-update btrfs snapshot if snapper is available
if command -v snapper >/dev/null 2>&1; then
    if [ "$TOTAL" -gt 0 ]; then
        log "Creating pre-update snapshot..."
        snapper -c root create -t pre -d "Pre-update snapshot (boot check)" 2>/dev/null || true
    fi
fi

log "Boot update check complete."
UPDEOF

chmod +x /usr/libexec/distro-bootloader/distro-update-check

# ==== Enable the update services ====
systemctl enable kaal-update-check.service 2>/dev/null || true
systemctl enable kaal-update-check.timer 2>/dev/null || true

# ==== Create Btrfs snapshot pre-update service ====
cat > /etc/systemd/system/distro-snapshot-pre-update.service << 'SNAPEOF'
[Unit]
Description=Create Btrfs snapshot before system update
Before=dnf5-pre-transaction.service

[Service]
Type=oneshot
ExecStart=/usr/libexec/distro-bootloader/distro-create-snapshot
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
SNAPEOF

# ==== Create first-boot service ====
cat > /etc/systemd/system/distro-first-boot.service << 'FBEOF'
[Unit]
Description=KAAL OS First Boot Setup
ConditionPathExists=!/etc/distro-bootloader/first-boot-done

[Service]
Type=oneshot
ExecStart=/usr/libexec/distro-bootloader/distro-first-boot
ExecStartPost=/bin/touch /etc/distro-bootloader/first-boot-done
RemainAfterExit=yes
StandardOutput=journal+console

[Install]
WantedBy=graphical-session.target
FBEOF

# ==== Create first-boot script ====
cat > /usr/libexec/distro-bootloader/distro-first-boot << 'FBSCRIPT'
#!/bin/bash
# KAAL OS First Boot Script
# Runs once on first boot after installation

set -euo pipefail

LOG="/var/log/distro-first-boot.log"
echo "KAAL OS First boot setup starting..." | tee "$LOG"

# 1. Detect GPU and configure driver
echo "Detecting GPU..." | tee -a "$LOG"
if lspci | grep -qi 'NVIDIA'; then
    echo "NVIDIA detected — ensuring driver is built..." | tee -a "$LOG"
    akmods --force 2>/dev/null || true
    systemctl enable nvidia-persistenced 2>/dev/null || true
    # Set NVIDIA modeset
    sed -i 's/.*nvidia-drm.modeset=.*/nvidia-drm.modeset=1/' /etc/default/grub 2>/dev/null || true
elif lspci | grep -qi 'AMD.*Radeon\|AMD.*RDNA'; then
    echo "AMD GPU detected — open-source driver already in kernel" | tee -a "$LOG"
elif lspci | grep -qi 'Intel'; then
    echo "Intel iGPU detected — driver already in kernel" | tee -a "$LOG"
fi

# 2. Regenerate initramfs with correct drivers
echo "Regenerating initramfs..." | tee -a "$LOG"
for kernel in /lib/modules/*/; do
    kver=$(basename "$kernel")
    dracut --force --kver "$kver" 2>/dev/null || true
done

# 3. Regenerate GRUB config
echo "Regenerating GRUB config..." | tee -a "$LOG"
if [ -d /sys/firmware/efi ]; then
    grub2-mkconfig -o /boot/efi/EFI/distro/grub.cfg 2>/dev/null || \
    grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
else
    grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
fi

# 4. Enable display manager based on installed DEs
if [ -x /usr/bin/sddm ]; then
    echo "Enabling SDDM..." | tee -a "$LOG"
    systemctl enable sddm 2>/dev/null || true
elif [ -x /usr/bin/gdm ]; then
    echo "Enabling GDM..." | tee -a "$LOG"
    systemctl enable gdm 2>/dev/null || true
fi

# 5. Set up zram
echo "Configuring zram..." | tee -a "$LOG"
if [ -f /etc/systemd/zram-generator.conf ]; then
    # Already configured by Fedora
    echo "zram already configured" | tee -a "$LOG"
else
    cat > /etc/systemd/zram-generator.conf << 'ZRAM'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
ZRAM
fi

# 6. Set up snapper for Btrfs snapshots
if command -v snapper >/dev/null 2>&1; then
    echo "Configuring snapper..." | tee -a "$LOG"
    if [ ! -f /etc/snapper/configs/root ]; then
        snapper -c root create-config -f btrfs / 2>/dev/null || true
    fi
    systemctl enable snapperd snapper-timeline.timer snapper-cleanup.timer 2>/dev/null || true
fi

# 7. Enable auto-update timer
echo "Enabling auto-update..." | tee -a "$LOG"
systemctl enable kaal-update-check.timer 2>/dev/null || true
systemctl enable kaal-update-check.service 2>/dev/null || true

# 8. Set up Plymouth theme
echo "Plymouth theme will be set up later (Phase 5)" | tee -a "$LOG"

# 9. Configure NetworkManager to auto-connect
echo "NetworkManager configured" | tee -a "$LOG"

# 10. Create live user if not exists
if ! id liveuser >/dev/null 2>&1; then
    echo "Live user not needed (installed system)" | tee -a "$LOG"
fi

echo "KAAL OS First boot setup complete!" | tee -a "$LOG"
FBSCRIPT

chmod +x /usr/libexec/distro-bootloader/distro-first-boot
systemctl enable distro-first-boot.service 2>/dev/null || true

# ==== Configure SDDM theme (placeholder) ====
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/distro.conf << 'SDDEOF'
[Theme]
# Theme will be configured in Phase 5
Current=
CursorTheme=
Font=

[Autologin]
# No autologin on installed system; live image autologins as liveuser
User=
Session=
SDDEOF

# ==== Configure GDM (placeholder) ====
mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf << 'GDMEOF'
# GDM config for KAAL OS
# Theme will be configured in Phase 5
[daemon]
WaylandEnable=true
AutomaticLoginEnable=false

[security]
DisallowRoot=true
GDMEOF

# ==== Create distro release info ====
cat > /etc/distro-release << 'RELEOF'
KAAL OS 0.1 (Live)
Codename: Genesis
Base: Fedora 42
Build Date: BUILD_DATE_PLACEHOLDER
RELEOF

# Create os-release
cat > /etc/os-release << 'OSEOF'
NAME="KAAL OS"
ID=distro
ID_LIKE=fedora
VERSION="0.1"
VERSION_ID="0.1"
PRETTY_NAME="KAAL OS 0.1 (Live)"
ANSI_COLOR="0;36"
HOME_URL="https://distro.example.com"
DOCUMENTATION_URL="https://docs.distro.example.com"
SUPPORT_URL="https://forum.distro.example.com"
BUG_REPORT_URL="https://bugs.distro.example.com"
REDHAT_BUGZILLA_PRODUCT="KAAL OS"
REDHAT_SUPPORT_PRODUCT="KAAL OS"
OSEOF

# ==== Create disto info directory ====
mkdir -p /usr/share/distro
cat > /usr/share/distro/info.json << 'INFOEOF'
{
    "name": "KAAL OS",
    "version": "0.1",
    "codename": "Genesis",
    "base": "fedora",
    "base_version": "42",
    "build_date": "BUILD_DATE_PLACEHOLDER",
    "profiles": ["gaming", "developer", "power-user", "daily", "minimal"],
    "desktop_environments": ["kde", "gnome", "hyprland", "sway", "xfce", "cinnamon"],
    "bootloaders": ["grub2", "systemd-boot"],
    "features": ["auto-update-on-boot", "btrfs-snapshots", "gpu-autodetect", "flatpak-first"]
}
INFOEOF

# ==== Configure Calamares installer ====
# Calamares config would go in /etc/calamares/
# This is a placeholder — full Calamares config is a separate task
mkdir -p /etc/calamares/modules

cat > /etc/calamares/settings.conf << 'CALEOF'
# KAAL OS Calamares master settings (from distro-calamares package)
---
sequence:
  - show:
      - welcome
      - profile-select
      - de-select
      - space-select
      - locale
      - keyboard
      - partition
      - bootloader-select
      - users
      - summary
  - exec:
      - partition
      - mount
      - unpackfs
      - machineid
      - fstab
      - locale
      - keyboard
      - users
      - distro-context
      - displaymanager
      - networkcfg
      - hwclock
      - services-systemd
      - bootloader
      - packages
      - luksbootkeyfile
      - plymouthcfg
      - initramfscfg
      - distro-post-install
      - removeuser
      - initramfs
      - finalize
  - show:
      - finished
branding: distro-default
branding-style: sidebar
allow-cancel: true
prompt-install: true
instances:
  - id: distro-post-install
    module: shellprocess
    config: distro-post-install.conf
CALEOF
# ==== Clean up ====
# Remove build artifacts
dnf clean all
rm -rf /var/cache/dnf/*
rm -rf /var/tmp/*
rm -rf /tmp/*

# Fix permissions
chmod 755 /usr/libexec/distro-bootloader/*

# Create log directory
mkdir -p /var/log/distro

# ---- KAAL visual identity: apply to live image (carried to install) ----
if [ -d /usr/share/kaal-visual ]; then
    bash /usr/share/kaal-visual/scripts/install-visual-identity.sh 2>/dev/null || \
        echo "[kaal] visual identity install skipped (non-fatal)"
fi

# ==== SELinux relabel (Fedora parity: enforcing in the live image too) ====
# Files copied in by this build (staged packages, themes, scripts, configs)
# must carry correct contexts before an enforcing boot. Targeted relabel
# during build; fall back to a boot-time relabel if it cannot run.
restorecon -R /etc /usr 2>/dev/null || fixfiles onboot || true

echo "KAAL OS kickstart post-install complete" | tee -a /root/distro-install.log
%end

# =============================================================================
# %post --nochroot — Copy files from build host into the image
# =============================================================================
%post --nochroot --erroronfail

# This runs on the build host, not inside the chroot.
# $LIVE_ROOT is the live image filesystem root.
# build-iso.sh stages all KAAL packages to /tmp/kaal-staging before running
# livemedia-creator, so every package is copied from there — never from the
# build machine's local paths.
STAGE="/tmp/kaal-staging"

if [ -d "$STAGE" ]; then
    # ---- distro-bootloader: etc + usr trees ----
    if [ -d "$STAGE/distro-bootloader/etc" ]; then
        echo "Staging bootloader package..."
        cp -r "$STAGE"/distro-bootloader/etc/* "$LIVE_ROOT/etc/" 2>/dev/null || true
        cp -r "$STAGE"/distro-bootloader/usr/* "$LIVE_ROOT/usr/" 2>/dev/null || true
        chmod +x "$LIVE_ROOT"/etc/grub.d/0*-distro* 2>/dev/null || true
        chmod +x "$LIVE_ROOT"/etc/grub.d/2*-distro* 2>/dev/null || true
        chmod +x "$LIVE_ROOT"/usr/libexec/distro-bootloader/* 2>/dev/null || true
    fi

    # ---- distro-iso-builder: profile lists + post-install scripts 01-07 ----
    if [ -d "$STAGE/distro-iso-builder/profiles" ]; then
        mkdir -p "$LIVE_ROOT/usr/share/distro/profiles"
        cp "$STAGE"/distro-iso-builder/profiles/*.list \
            "$LIVE_ROOT/usr/share/distro/profiles/" 2>/dev/null || true
    fi
    if [ -d "$STAGE/distro-iso-builder/scripts" ]; then
        mkdir -p "$LIVE_ROOT/usr/libexec/distro-installer"
        cp "$STAGE"/distro-iso-builder/scripts/*.sh \
            "$LIVE_ROOT/usr/libexec/distro-installer/" 2>/dev/null || true
    fi

    # ---- distro-hardware: post-install scripts 08-16 ----
    if [ -d "$STAGE/distro-hardware/scripts" ]; then
        mkdir -p "$LIVE_ROOT/usr/libexec/distro-installer"
        cp "$STAGE"/distro-hardware/scripts/*.sh \
            "$LIVE_ROOT/usr/libexec/distro-installer/" 2>/dev/null || true
    fi

    # ---- distro-calamares: modules + branding + configs ----
    if [ -d "$STAGE/distro-calamares" ]; then
        mkdir -p "$LIVE_ROOT/etc/calamares" "$LIVE_ROOT/usr/lib/calamares"
        cp -r "$STAGE"/distro-calamares/modules/* \
            "$LIVE_ROOT/usr/lib/calamares/modules/" 2>/dev/null || true
        cp -r "$STAGE"/distro-calamares/branding/* \
            "$LIVE_ROOT/usr/lib/calamares/branding/" 2>/dev/null || true
        cp "$STAGE"/distro-calamares/settings.conf \
            "$LIVE_ROOT/etc/calamares/" 2>/dev/null || true
        mkdir -p "$LIVE_ROOT/etc/calamares/modules"
        cp "$STAGE"/distro-calamares/modules/*/*.conf \
            "$LIVE_ROOT/etc/calamares/modules/" 2>/dev/null || true
        cp "$STAGE"/distro-calamares/modules/distro-post-install.conf \
            "$LIVE_ROOT/etc/calamares/modules/" 2>/dev/null || true
    fi

    # ---- kaal-spaces: etc + usr trees + script 17 ----
    if [ -d "$STAGE/kaal-spaces" ]; then
        cp -r "$STAGE"/kaal-spaces/etc/* "$LIVE_ROOT/etc/" 2>/dev/null || true
        cp -r "$STAGE"/kaal-spaces/usr/* "$LIVE_ROOT/usr/" 2>/dev/null || true
        cp "$STAGE"/kaal-spaces/scripts/17-spaces-setup.sh \
            "$LIVE_ROOT/usr/libexec/distro-installer/" 2>/dev/null || true
        chmod +x "$LIVE_ROOT"/usr/libexec/kaal-spaces/* 2>/dev/null || true
        chmod +x "$LIVE_ROOT"/usr/libexec/kaal-spaces/panels/* 2>/dev/null || true
        chmod +x "$LIVE_ROOT"/usr/libexec/kaal-spaces/hooks/* 2>/dev/null || true
    fi

    # ---- kaal-visual: full tree (applied during ISO build chroot post) ----
    if [ -d "$STAGE/kaal-visual" ]; then
        mkdir -p "$LIVE_ROOT/usr/share/kaal-visual"
        cp -r "$STAGE"/kaal-visual/* "$LIVE_ROOT/usr/share/kaal-visual/" 2>/dev/null || true
    fi

    # ---- kaal-security: config + usr trees + scripts 18-21 ----
    if [ -d "$STAGE/kaal-security" ]; then
        mkdir -p "$LIVE_ROOT/usr/share/kaal-security"
        cp -r "$STAGE"/kaal-security/config \
            "$LIVE_ROOT/usr/share/kaal-security/" 2>/dev/null || true
        cp -r "$STAGE"/kaal-security/usr/* "$LIVE_ROOT/usr/" 2>/dev/null || true
        chmod +x "$LIVE_ROOT"/usr/bin/kaal-antivirus "$LIVE_ROOT"/usr/bin/kaal-vpn \
            2>/dev/null || true
        cp "$STAGE"/kaal-security/scripts/*.sh \
            "$LIVE_ROOT/usr/libexec/distro-installer/" 2>/dev/null || true
    fi

    # Executable bit for all installer scripts (01-21)
    chmod +x "$LIVE_ROOT"/usr/libexec/distro-installer/*.sh 2>/dev/null || true
else
    echo "WARNING: $STAGE not found — staged packages NOT copied into image!" >&2
    echo "Run ./build-iso.sh from packages/distro-iso-builder/ so it can stage them." >&2
fi

%end
