#!/bin/bash
# =============================================================================
# config.sh — KAAL OS image customisation for the kiwi build
# =============================================================================
# Runs chrooted INSIDE the image root during `kiwi-ng system build`, before the
# ISO is packed. It is the kiwi equivalent of the %post section of
# distro-live.ks, and it ports that block faithfully rather than re-inventing it.
#
# One deliberate difference from anaconda: there is no $ANA_INSTALL_PATH and no
# /mnt/sysimage here. kiwi copies everything under the description's `root/`
# directory into the image, so the build stages the seven KAAL packages to
# kiwi/root/kaal-staging/ on the host and they arrive at /kaal-staging inside
# the image. Every path below is therefore relative to /, not to a mountpoint.
#
# Failures are fatal on purpose. The staging block in distro-live.ks used to
# fail silently and shipped an image with no installer config; that is exactly
# the class of bug this rewrite must not inherit.
# =============================================================================
set -euo pipefail

STAGE="/kaal-staging"
echo "== KAAL OS: customising image (kiwi config.sh) =="

# ---- 1. Identity -----------------------------------------------------------
cat > /etc/os-release << 'EOF'
NAME="KAAL OS"
ID=kaal
ID_LIKE=fedora
VERSION="0.1.0"
PRETTY_NAME="KAAL OS 0.1.0 (Live)"
ANSI_COLOR="0;36"
HOME_URL="https://github.com/pujariseema93-beep/kaal-os"
EOF
echo "kaal-live" > /etc/hostname

# ---- 2. Stage the seven KAAL packages into the image ------------------------
# Ported from the %post block of distro-live.ks. If you change the layout of a
# package, change it here too — this is now the only place it is applied.
if [ -d "$STAGE" ]; then

    # ---- distro-bootloader: etc + usr trees ----
    if [ -d "$STAGE/distro-bootloader/etc" ]; then
        echo "Staging bootloader package..."
        cp -r "$STAGE"/distro-bootloader/etc/* /etc/
        cp -r "$STAGE"/distro-bootloader/usr/* /usr/
        chmod +x /etc/grub.d/0*-distro* 2>/dev/null || true
        chmod +x /etc/grub.d/2*-distro* 2>/dev/null || true
        chmod +x /usr/libexec/distro-bootloader/* 2>/dev/null || true
    fi

    # ---- distro-iso-builder: profile lists + post-install scripts 01-07 ----
    if [ -d "$STAGE/distro-iso-builder/profiles" ]; then
        mkdir -p /usr/share/distro/profiles
        cp "$STAGE"/distro-iso-builder/profiles/*.list /usr/share/distro/profiles/
    fi
    if [ -d "$STAGE/distro-iso-builder/scripts" ]; then
        mkdir -p /usr/libexec/distro-installer
        cp "$STAGE"/distro-iso-builder/scripts/*.sh /usr/libexec/distro-installer/
    fi

    # ---- distro-hardware: post-install scripts 08-16 ----
    if [ -d "$STAGE/distro-hardware/scripts" ]; then
        mkdir -p /usr/libexec/distro-installer
        cp "$STAGE"/distro-hardware/scripts/*.sh /usr/libexec/distro-installer/
    fi

    # ---- distro-calamares: modules + branding + settings ----
    # modules-search "local" resolves to $LIBDIR/calamares/modules, which on
    # Fedora 44 is /usr/lib64/calamares/modules. Install into both so the
    # modules are found at runtime whichever path Calamares resolves.
    if [ -d "$STAGE/distro-calamares" ]; then
        mkdir -p /etc/calamares /etc/calamares/modules \
                 /usr/lib/calamares/modules /usr/lib64/calamares/modules \
                 /usr/lib/calamares/branding
        cp -r "$STAGE"/distro-calamares/modules/* /usr/lib/calamares/modules/
        cp -r "$STAGE"/distro-calamares/modules/* /usr/lib64/calamares/modules/
        cp -r "$STAGE"/distro-calamares/branding/* /usr/lib/calamares/branding/
        cp "$STAGE"/distro-calamares/settings.conf /etc/calamares/
        cp "$STAGE"/distro-calamares/modules/*/*.conf /etc/calamares/modules/ 2>/dev/null || true
        cp "$STAGE"/distro-calamares/modules/distro-post-install.conf /etc/calamares/modules/
    fi

    # ---- kaal-spaces: etc + usr trees + its installer script ----
    if [ -d "$STAGE/kaal-spaces" ]; then
        cp -r "$STAGE"/kaal-spaces/etc/* /etc/
        cp -r "$STAGE"/kaal-spaces/usr/* /usr/
        cp "$STAGE"/kaal-spaces/scripts/*.sh /usr/libexec/distro-installer/ 2>/dev/null || true
        chmod +x /usr/libexec/kaal-spaces/* 2>/dev/null || true
        chmod +x /usr/libexec/kaal-spaces/panels/* 2>/dev/null || true
        chmod +x /usr/libexec/kaal-spaces/hooks/* 2>/dev/null || true
    fi

    # ---- kaal-visual: whole tree, applied by the ISO build chroot ----
    if [ -d "$STAGE/kaal-visual" ]; then
        mkdir -p /usr/share/kaal-visual
        cp -r "$STAGE"/kaal-visual/* /usr/share/kaal-visual/
    fi

    # ---- kaal-security + kaal-monitor ----
    if [ -d "$STAGE/kaal-security" ]; then
        mkdir -p /usr/share/kaal-security
        cp -r "$STAGE"/kaal-security/config /usr/share/kaal-security/
        cp -r "$STAGE"/kaal-security/usr/* /usr/
        [ -d "$STAGE/kaal-monitor/usr" ] && cp -r "$STAGE"/kaal-monitor/usr/* /usr/
        chmod +x /usr/bin/kaal-monitor 2>/dev/null || true
        chmod +x /usr/bin/kaal-antivirus /usr/bin/kaal-vpn 2>/dev/null || true
        cp "$STAGE"/kaal-security/scripts/*.sh /usr/libexec/distro-installer/ 2>/dev/null || true
    fi

    chmod +x /usr/libexec/distro-installer/*.sh 2>/dev/null || true

    # ---- Prove it landed, or fail the build -----------------------------
    MISSING=0
    for f in /etc/calamares/settings.conf \
             /usr/share/distro/profiles \
             /usr/libexec/distro-installer; do
        if [ ! -e "$f" ]; then
            echo "FATAL: staged content missing in image: $f" >&2
            MISSING=1
        fi
    done
    if [ -z "$(ls -A /usr/libexec/distro-installer 2>/dev/null)" ]; then
        echo "FATAL: no installer scripts in /usr/libexec/distro-installer" >&2
        MISSING=1
    fi
    if [ "$MISSING" -ne 0 ]; then
        echo "FATAL: the staged packages did not reach the image." >&2
        exit 1
    fi
    echo "KAAL staging: verified — installer scripts, profiles and Calamares config are in the image"
else
    echo "FATAL: $STAGE not found — the build did not stage the KAAL packages." >&2
    echo "The workflow must copy packages/* into kiwi/root/kaal-staging/ before kiwi runs." >&2
    exit 1
fi

# ---- 3. Live user -----------------------------------------------------------
# An EMPTY password is refused by PAM on this image ("Login incorrect"), and
# chpasswd goes through pam_pwquality which can reject a short one silently.
# Write the hash directly, exactly as distro-live.ks does.
if id liveuser >/dev/null 2>&1; then
    LIVE_HASH=$(openssl passwd -6 "kaal-live")
    usermod -p "$LIVE_HASH" liveuser
    echo "live user ready: liveuser / kaal-live"
else
    echo "WARNING: liveuser does not exist — the live session cannot work" >&2
fi

# ---- 4. Live session: SDDM autologin ---------------------------------------
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/kaal-live.conf << 'EOF'
[Autologin]
User=liveuser
Session=plasma
Relogin=true

[Theme]
Current=kaal
EOF

# ---- 5. Services ------------------------------------------------------------
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable sddm 2>/dev/null || true
systemctl set-default graphical.target 2>/dev/null || true

# ---- 6. Cleanup -------------------------------------------------------------
dnf clean all 2>/dev/null || true
rm -rf /var/cache/dnf/* /var/tmp/* /tmp/* 2>/dev/null || true
truncate -s 0 /var/log/*.log 2>/dev/null || true

echo "== KAAL OS: customisation complete =="
