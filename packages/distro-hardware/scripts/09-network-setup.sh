#!/bin/bash
# =============================================================================
# 09-network-setup.sh — Network & WiFi Configuration
# =============================================================================
# Configures NetworkManager, WiFi, wpa_supplicant, hotspot support,
# DNS, and firewall. Ensures the user can connect to WiFi out of the box.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Network & WiFi Setup ==="

# ---- Install network packages ----
echo "Installing network packages..."
dnf5 install -y \
    NetworkManager \
    NetworkManager-wifi \
    NetworkManager-bluetooth \
    NetworkManager-ppp \
    NetworkManager-openvpn \
    NetworkManager-openvpn-gnome \
    NetworkManager-vpnc \
    NetworkManager-vpnc-gnome \
    NetworkManager-libreswan \
    NetworkManager-wwan \
    NetworkManager-adsl \
    wpa_supplicant \
    dhclient \
    dnsmasq \
    bind-utils \
    iproute \
    iputils \
    iw \
    iwd \
    network-manager-applet \
    plasma-nm \
    2>/dev/null || true

# ---- Enable NetworkManager ----
echo "Enabling NetworkManager..."
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable NetworkManager-wait-online.service 2>/dev/null || true

# ---- Configure NetworkManager ----
mkdir -p /etc/NetworkManager/conf.d

# Enable WiFi
cat > /etc/NetworkManager/conf.d/wifi.conf << 'WIFI'
# KAAL OS WiFi configuration
[device]
wifi.backend=wpa_supplicant

[connection]
# Auto-connect to WiFi when available
wifi.powersave=3
# 0=disable, 1=enable, 2=ignore, 3=enable when on battery
WIFI

# Enable connection sharing (for hotspot)
cat > /etc/NetworkManager/conf.d/shared.conf << 'SHARE'
# KAAL OS Connection sharing (hotspot) config
[connection]
# Allow creating WiFi hotspots
ipv4.method=shared
ipv6.method=ignore
SHARE

# ---- Configure wpa_supplicant ----
# wpa_supplicant is managed by NetworkManager on modern systems
# but ensure the service is available
mkdir -p /etc/wpa_supplicant

# ---- DNS configuration ----
# Use systemd-resolved for DNS caching and DNS-over-TLS
echo "Configuring DNS..."
dnf5 install -y systemd-resolved 2>/dev/null || true
systemctl enable systemd-resolved 2>/dev/null || true

# Set NetworkManager to use systemd-resolved
cat > /etc/NetworkManager/conf.d/dns.conf << 'DNS'
# KAAL OS DNS configuration
[main]
dns=systemd-resolved
DNS

# ---- Firewall configuration ----
echo "Configuring firewall..."
dnf5 install -y firewalld firewall-config firewall-applet 2>/dev/null || true
systemctl enable firewalld 2>/dev/null || true

# Default zone: public (allows SSH, DHCP, DNS, mDNS)
# Allow WiFi, Bluetooth, and common services
firewall-offline-cmd --zone=public --add-service=ssh 2>/dev/null || true
firewall-offline-cmd --zone=public --add-service=dhcpv6-client 2>/dev/null || true
firewall-offline-cmd --zone=public --add-service=mdns 2>/dev/null || true
firewall-offline-cmd --zone=public --add-service=http 2>/dev/null || true
firewall-offline-cmd --zone=public --add-service=https 2>/dev/null || true
firewall-offline-cmd --zone=public --add-service=samba-client 2>/dev/null || true

# ---- Hostname ----
if [ -f /etc/distro-bootloader/install-context.conf ]; then
    source /etc/distro-bootloader/install-context.conf
    HOSTNAME="${DISTRO_HOSTNAME:-distro}"
else
    HOSTNAME="distro"
fi
echo "$HOSTNAME" > /etc/hostname

# ---- hosts file ----
cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
HOSTS

# Add hostname to hosts
echo "127.0.1.1   $HOSTNAME" >> /etc/hosts

# ---- VPN support ----
# OpenVPN and WireGuard are already installed in the base, ensure configs:
mkdir -p /etc/NetworkManager/system-connections

# ---- IPv6 privacy extensions ----
cat > /etc/sysctl.d/99-distro-network.conf << 'SYSCTL'
# KAAL OS Network sysctl tuning

# IPv6 privacy extensions (use temporary addresses)
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2

# Accept router advertisements
net.ipv6.conf.all.accept_ra = 1
net.ipv6.conf.default.accept_ra = 1

# Protect against spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
SYSCTL

echo "=== Network & WiFi Setup Complete ==="
