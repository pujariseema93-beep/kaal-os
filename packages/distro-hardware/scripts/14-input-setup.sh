#!/bin/bash
# =============================================================================
# 14-input-setup.sh — Input Device Configuration
# =============================================================================
# Configures touchpad (gestures, natural scrolling, tap-to-click),
# Wacom tablet support, keyboard backlight, and gaming controller
# support.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Input Device Setup ==="

# ---- Install input packages ----
echo "Installing input device packages..."
dnf5 install -y \
    libinput \
    xf86-input-libinput \
    xorg-x11-drv-libinput \
    synaptics \
    wacomtablet \
    xorg-x11-drv-wacom \
    libwacom \
    libwacom-data \
    touchegg \
    touchegg-gnome \
    2>/dev/null || true

# ---- Source context for DE ----
DE="kde"
if [ -f /etc/distro-bootloader/install-context.conf ]; then
    source /etc/distro-bootloader/install-context.conf
    DE="${DISTRO_DE:-kde}"
fi

# ---- libinput configuration (applies to all DEs) ----
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/40-libinput.conf << 'LIBINPUT'
# KAAL OS libinput touchpad configuration

Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"

    # Natural scrolling (swipe down = scroll down)
    Option "NaturalScrolling" "true"

    # Tap to click
    Option "Tapping" "on"

    # Tap-and-drag (hold after tap to drag)
    Option "TappingDrag" "on"

    # Tap-and-drag lock (keep dragging after releasing)
    Option "TappingDragLock" "off"

    # Click method: clickfinger (2-finger right click) or button areas
    Option "ClickMethod" "clickfinger"

    # Middle button emulation
    Option "MiddleEmulation" "off"

    # Disable while typing
    Option "DisableWhileTyping" "true"

    # Disable on external mouse
    Option "DisableWhileTyping" "true"

    # Scroll method: twofinger
    Option "ScrollMethod" "twofinger"

    # Horizontal scrolling
    Option "ScrollHorizontal" "true"

    # Speed (0 = none, 1 = max)
    Option "AccelSpeed" "0.3"

    # Acceleration profile (flat = no acceleration, adaptive = default)
    Option "AccelProfile" "flat"

    # Send device events mode
    Option "SendEventsMode" "on"
EndSection

Section "InputClass"
    Identifier "libinput keyboard catchall"
    MatchIsKeyboard "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    Option "XkbLayout" "us"
    Option "XkbVariant" ""
EndSection

Section "InputClass"
    Identifier "libinput trackpoint catchall"
    MatchIsPointer "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    # Trackpoint (ThinkPad nub) sensitivity
    Option "AccelSpeed" "0.5"
    Option "AccelProfile" "flat"
EndSection
LIBINPUT

# ---- X11 touchpad config (for XFCE/Cinnamon) ----
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/90-touchpad.conf << 'TOUCH'
# KAAL OS Touchpad configuration (X11)
Section "InputClass"
    Identifier "touchpad"
    MatchIsTouchpad "yes"
    Driver "libinput"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "ScrollMethod" "twofinger"
    Option "ClickMethod" "clickfinger"
    Option "DisableWhileTyping" "true"
EndSection
TOUCH

# ---- KDE Plasma input config ----
if [ "$DE" = "kde" ]; then
    echo "Configuring KDE Plasma touchpad..."
    mkdir -p /etc/skel/.config
    cat > /etc/skel/.config/touchpadrc << 'TOUCHKDE'
# KAAL OS KDE Plasma touchpad config
[parameters]
InvertScroll=true
TapToClick=true
MiddleButtonEmulation=false
DisableWhileTyping=true
NaturalScrolling=true
ClickFingerTap=true
ScrollMethod=twoFinger
TOUCHKDE
fi

# ---- GNOME input config ----
if [ "$DE" = "gnome" ]; then
    echo "Configuring GNOME touchpad..."
    mkdir -p /etc/dconf/db/local.d
    cat > /etc/dconf/db/local.d/distro-input << 'GNOMEIN'
# KAAL OS GNOME input settings
[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
natural-scroll=true
disable-while-typing=true
click-method='fingers'
send-events='on'

[org/gnome/desktop/peripherals/keyboard]
delay=250
repeat-interval=30
GNOMEIN
    dconf update 2>/dev/null || true
fi

# ---- Wacom tablet configuration ----
echo "Configuring Wacom tablet support..."
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/50-wacom.conf << 'WACOM'
# KAAL OS Wacom tablet configuration
Section "InputClass"
    Identifier "Wacom"
    MatchProduct "Wacom|WACOM|PTK-540WL|FT-0405-U|PenStation"
    MatchDevicePath "/dev/input/event*"
    Driver "wacom"
    # Map to entire desktop
    Option "MapToOutput" "eDP-1"
    # Rotation: none, cw, ccw, half
    Option "Rotate" "none"
    # Pressure curve (0-100)
    Option "PressCurve" "0,0,100,100"
EndSection
WACOM

# ---- Keyboard backlight configuration ----
# For laptops with RGB keyboard backlight (e.g., Lenovo Legion, ASUS ROG)
mkdir -p /etc/systemd/system
cat > /etc/systemd/system/distro-keyboard-backlight.service << 'KB'
[Unit]
Description=KAAL OS Keyboard Backlight Setup
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=/usr/libexec/distro-hardware/distro-keyboard-backlight
RemainAfterExit=yes

[Install]
WantedBy=graphical-session.target
KB

cat > /usr/libexec/distro-hardware/distro-keyboard-backlight << 'KBB'
#!/bin/bash
# Set default keyboard backlight on boot

set -euo pipefail

# Set keyboard backlight to 50% on boot
# Works with:
#   - /sys/class/leds/tpacpi::kbd_backlight (ThinkPad)
#   - /sys/class/leds/asus::kbd_backlight (ASUS)
#   - /sys/class/leds/msi::kbd_backlight (MSI)
#   - /sys/class/leds/:*kbd_backlight (generic)

for bl in /sys/class/leds/*kbd_backlight/brightness; do
    if [ -f "$bl" ]; then
        max=$(cat "$(dirname "$bl")/max_brightness" 2>/dev/null || echo 2)
        level=$((max / 2))
        echo "$level" > "$bl" 2>/dev/null || true
        echo "Set keyboard backlight to $level/$max"
    fi
done

# RGB keyboard (ASUS ROG, Lenovo Legion)
if [ -d /sys/class/leds/asus::kbd_backlight ]; then
    # Install openrgb or asusctl for RGB control
    echo "ASUS RGB keyboard detected"
fi
KBB
chmod +x /usr/libexec/distro-hardware/distro-keyboard-backlight
systemctl enable distro-keyboard-backlight.service 2>/dev/null || true

# ---- Gaming controller support ----
echo "Configuring gaming controller support..."
dnf5 install -y \
    steam-devices \
    joystick-support \
    jstest-gtk \
    antimicrox \
    2>/dev/null || true

# udev rules for game controllers
cat > /etc/udev/rules.d/99-controllers.rules << 'CTRL'
# KAAL OS Gaming controller udev rules

# Steam Deck / Steam Controller
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="28de", MODE="0666"

# Xbox One / Series X|S controller
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="045e", MODE="0666"

# DualShock 4 / DualSense (PS4/PS5)
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="054c", MODE="0666"

# Nintendo Switch Pro Controller
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="057e", MODE="0666"

# 8BitDo controllers
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2dc8", MODE="0666"

# Generic permission for all game controllers
SUBSYSTEM=="input", ATTRS{name}=="*Xbox*|*DualShock*|*DualSense*|*Switch*|*Steam*|*8BitDo*", MODE="0666"
CTRL

echo "=== Input Device Setup Complete ==="
