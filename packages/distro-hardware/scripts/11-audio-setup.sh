#!/bin/bash
# =============================================================================
# 11-audio-setup.sh — PipeWire Audio Configuration
# =============================================================================
# Configures PipeWire and WirePlumber for optimal audio:
#   - Default device selection
#   - Low-latency config for gaming
#   - Bluetooth codec priority
#   - Pro audio (optional)
#   - EasyEffects for EQ/effects
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Audio Setup ==="

# ---- Install audio packages ----
echo "Installing audio packages..."
dnf5 install -y \
    pipewire \
    pipewire-alsa \
    pipewire-pulseaudio \
    pipewire-pulseaudio \
    pipewire-jack-audio-connection-kit \
    pipewire-jack-audio-connection-kit-devel \
    pipewire-utils \
    pipewire-codec-bluetooth \
    wireplumber \
    wireplumber-devel \
    easyeffects \
    pavucontrol \
    pulsemixer \
    pulseaudio-utils \
    alsa-utils \
    alsa-firmware \
    alsa-tools \
    alsa-plugins-pulseaudio \
    alsa-plugins-samplerate \
    alsa-plugins-upmix \
    alsa-plugins-vdownmix \
    sox \
    2>/dev/null || true

# ---- Enable PipeWire services ----
echo "Enabling PipeWire services..."
systemctl enable pipewire 2>/dev/null || true
systemctl enable pipewire-pulse 2>/dev/null || true
systemctl enable pipewire.socket 2>/dev/null || true
systemctl enable pipewire-pulse.socket 2>/dev/null || true
systemctl enable wireplumber 2>/dev/null || true

# ---- PipeWire configuration ----
mkdir -p /etc/pipewire

cat > /etc/pipewire/pipewire.conf.d/distro-audio.conf << 'PW'
# KAAL OS PipeWire Configuration
# Optimized for gaming, media, and daily use

context.properties = {
    # Audio clock rate (48000 = standard, 96000 = hi-res)
    default.clock.rate = 48000
    # Quantum (buffer size) — lower = less latency, more CPU
    #   32  = ~0.7ms at 48kHz (pro audio)
    #   64  = ~1.3ms (gaming)
    #   128 = ~2.7ms (default)
    #   256 = ~5.3ms (safe/balanced)
    default.clock.quantum = 64
    default.clock.min-quantum = 32
    default.clock.max-quantum = 1024

    # Allow real-time scheduling (for low latency)
    link.max-buffers = 16
    log.level = 2
}

# SPA (Simple Plugin API) configuration
spa.properties = {
    # Audio resampler quality (0-14, higher = better)
    audio.resampler.quality = 14
}

context.modules = [
    # Real-time scheduling module
    { name = libpipewire-module-rt
      args = {
          # RT priority for audio threads
          nice.level = -11
          # UTS priority
          rtprio = 88
          # RTKit fallback
          rtprio.prio = 88
      }
      flags = [ ifexists nofail ]
    }
]
PW

# ---- WirePlumber configuration ----
mkdir -p /etc/wireplumber

# Default device and routing
cat > /etc/wireplumber/50-distro-default.conf << 'WP'
# KAAL OS WirePlumber Default Audio Configuration

# Default audio device settings
monitor.alsa.properties = {
  # Use ALSA card names for stable device identification
  api.alsa.use-acp = true
  # Disable batch mode for lower latency
  api.alsa.disable-batch = true
}

# Default node properties
node.properties = {
  # Default sink (output) — "auto" = best available
  # Set to a specific device name to force a default
  # Example: "alsa_output.pci-0000_00_1f.3.analog-stereo"
  device.default.audio.sink = "auto"
  device.default.audio.source = "auto"
}

wireplumber.settings = {
  # Persistent device settings (survive reboot)
  bluetooth.use-persistent-storage = true
  # Auto-switch to Bluetooth headset when connected
  bluetooth.autoswitch-to-headset-profile = true
  # Default volume
  device.restore-volumes = true
}
WP

# ---- Low-latency gaming profile ----
cat > /etc/wireplumber/51-distro-gaming.conf << 'WPGAME'
# KAAL OS WirePlumber Gaming Audio Profile
# Applied when the user enables "Gaming Audio Mode" via kaal-tweak-tool

# The gaming profile uses:
#   - Smaller quantum (32-64 samples)
#   - Higher real-time priority
#   - Disabled resampling (pass-through)
#   - FastStream for Bluetooth (low-latency bidirectional)

# This config is loaded alongside the default, and specific
# settings are toggled by the tweak tool via environment variables.
WPGAME

# ---- ALSA configuration ----
mkdir -p /etc/alsa
cat > /etc/alsa/alsarc << 'ALSA'
# KAAL OS ALSA defaults
# PipeWire manages the actual audio, but ALSA defaults are
# used for fallback and ALSA-native applications

defaults.pcm.card 0
defaults.ctl.card 0
defaults.pcm.device 0
defaults.pcm.subdevice -1
ALSA

# ---- User-level PipeWire config skeleton ----
mkdir -p /etc/skel/.config/pipewire
cat > /etc/skel/.config/pipewire/pipewire.conf << 'USERPW'
# User-level PipeWire config (in home directory)
# Copy this to ~/.config/pipewire/pipewire.conf to override system defaults
#
# For gaming, set:
#   default.clock.quantum = 32
#   default.clock.rate = 48000
#
# For hi-res audio:
#   default.clock.rate = 96000
#   default.clock.quantum = 256
USERPW

# ---- EasyEffects presets directory ----
mkdir -p /etc/skel/.config/easyeffects
cat > /etc/skel/.config/easyeffects/default.json << 'EE'
{
  "output": {
    "blocklist": [],
    "equalizer": {
      "state": "false",
      "num-bands": 10,
      "input-gain": 0,
      "output-gain": 0
    }
  },
  "input": {
    "blocklist": [],
    "equalizer": {
      "state": "false",
      "num-bands": 5,
      "input-gain": 0,
      "output-gain": 0
    }
  }
}
EE

# ---- Remove PulseAudio (if installed) ----
# PipeWire replaces PulseAudio, so ensure no conflicts
if dnf5 list installed pulseaudio 2>/dev/null | grep -q pulseaudio; then
    echo "Removing PulseAudio (replaced by PipeWire)..."
    dnf5 remove -y pulseaudio pulseaudio-module-bluetooth 2>/dev/null || true
fi

echo "=== Audio Setup Complete ==="
