#!/bin/bash
# =============================================================================
# 05-auto-update-setup.sh — Auto-Update Service Setup (Post-Install)
# =============================================================================
# Configures the boot-triggered auto-update system on the installed system.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Auto-Update System Setup ==="

# ---- Create the systemd service (if not already from kickstart) ----
if [ ! -f "/etc/systemd/system/kaal-update-check.service" ]; then
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

[Install]
WantedBy=graphical-session.target
SVCEOF
fi

# ---- Create the timer ----
if [ ! -f "/etc/systemd/system/kaal-update-check.timer" ]; then
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
fi

# ---- Create the update check script (if not already from kickstart) ----
if [ ! -f /usr/libexec/distro-bootloader/distro-update-check ]; then
    mkdir -p /usr/libexec/distro-bootloader

    cat > /usr/libexec/distro-bootloader/distro-update-check << 'UPDEOF'
#!/bin/bash
set -euo pipefail
LOG="/var/log/distro-update-check.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

log "Starting boot update check..."

# Check DNF
DNF_UPDATES=$(dnf5 check-update --quiet 2>/dev/null | grep -c '\.rpm' || echo "0")
# Check Flatpak
FLATPAK_UPDATES=$(flatpak update --no-deploy --no-interaction 2>/dev/null | grep -c '^\s' || echo "0")
# Check firmware
fwupdmgr refresh --quiet 2>/dev/null || true
FW_UPDATES=$(fwupdmgr get-updates --quiet 2>/dev/null | grep -c 'Update available' || echo "0")

TOTAL=$((DNF_UPDATES + FLATPAK_UPDATES + FW_UPDATES))
log "Found: DNF=$DNF_UPDATES Flatpak=$FLATPAK_UPDATES Firmware=$FW_UPDATES Total=$TOTAL"

if [ "$TOTAL" -gt 0 ]; then
    # Download DNF updates in background
    log "Downloading updates..."
    dnf5 download --allowerasing --quiet $(dnf5 check-update --quiet 2>/dev/null | awk '{print $1}' | head -50) 2>/dev/null || true

    # Create pre-update snapshot
    if command -v snapper >/dev/null 2>&1; then
        log "Creating pre-update snapshot..."
        snapper -c root create -t pre -d "Pre-update (boot check)" 2>/dev/null || true
    fi

    # Notify user
    if command -v notify-send >/dev/null 2>&1; then
        export DISPLAY=:0
        UID_NUM=$(id -u "$(ls /home | head -1)" 2>/dev/null || echo 1000)
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$UID_NUM/bus"
        notify-send -u normal -a "KAAL OS Update Checker" \
            "$TOTAL updates available" \
            "Run: sudo dnf5 upgrade" 2>/dev/null || true
    fi
    log "Notification sent for $TOTAL updates"
else
    log "System is up to date"
fi
log "Boot update check complete."
UPDEOF

    chmod +x /usr/libexec/distro-bootloader/distro-update-check
fi

# ---- Enable the services ----
systemctl enable kaal-update-check.service 2>/dev/null || true
systemctl enable kaal-update-check.timer 2>/dev/null || true

# ---- Create update preferences config ----
mkdir -p /etc/distro-bootloader

cat > /etc/distro-bootloader/update-preferences.conf << 'PREFEOF'
# KAAL OS Update Preferences
# Editable via kaal-update-preferences GUI

# Mode: manual | auto-install | silent
#   manual:       download + notify, user installs
#   auto-install: download + install automatically, prompt for reboot
#   silent:       download + install silently, only notify if reboot needed
MODE=manual

# Check interval in hours (for timer-based checks between reboots)
CHECK_INTERVAL_HOURS=4

# Download on metered connections (true/false)
DOWNLOAD_METERED=false

# Auto-snapshot before update (requires snapper or timeshift)
AUTO_SNAPSHOT=true

# Maximum download speed in KB/s (0 = unlimited)
MAX_SPEED_KBPS=0

# Enable firmware updates (true/false)
FIRMWARE_UPDATES=true

# Enable Flatpak updates (true/false)
FLATPAK_UPDATES=true
PREFEOF

# ---- Create DNF automatic update config ----
cat > /etc/dnf/automatic.conf << 'DNFAUTOEOF'
# KAAL OS DNF Automatic Configuration
# This handles downloading updates in the background

[commands]
# What to do: download-only, apply, or just notify
upgrade_type = default
random_sleep = 300
download_updates = yes
apply_updates = no
emit_via = stdio

[email]
email_from = root@localhost
email_to = root
email_host = localhost

[base]
debuglevel = 1
DNFAUTOEOF

echo "Auto-update system configured:"
echo "  Mode: manual (change via kaal-update-preferences)"
echo "  Check: on boot + every 4 hours"
echo "  Snapshot: auto before update"
echo "=== Auto-Update System Setup Complete ==="
