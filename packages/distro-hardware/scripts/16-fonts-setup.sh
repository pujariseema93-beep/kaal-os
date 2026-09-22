#!/bin/bash
# =============================================================================
# 16-fonts-setup.sh — Font & Text Rendering Configuration
# =============================================================================
# Installs comprehensive font packages (Latin, CJK, Indic, Arabic,
# emoji), configures subpixel rendering, hinting, and fontconfig
# defaults for crisp, clear text on all displays.
# =============================================================================

set -euo pipefail

echo "=== KAAL OS Font & Rendering Setup ==="

# ---- Install font packages ----
echo "Installing font packages..."

# Latin / Western fonts
dnf5 install -y \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    google-noto-sans-mono-fonts \
    google-noto-display-fonts \
    dejavu-sans-fonts \
    dejavu-serif-fonts \
    dejavu-sans-mono-fonts \
    liberation-fonts \
    google-roboto-fonts \
    google-roboto-mono-fonts \
    google-roboto-slab-fonts \
    inter-fonts \
    ibm-plex-sans-fonts \
    ibm-plex-mono-fonts \
    ibm-plex-serif-fonts \
    jetbrains-mono-fonts \
    fira-code-fonts \
    fira-sans-fonts \
    hack-fonts \
    source-code-pro-fonts \
    source-sans-pro-fonts \
    source-serif-pro-fonts \
    2>/dev/null || true

# CJK fonts (Chinese, Japanese, Korean)
dnf5 install -y \
    google-noto-sans-cjk-fonts \
    google-noto-sans-cjk-ttc-fonts \
    google-noto-serif-cjk-fonts \
    adobe-source-han-sans-cn-fonts \
    adobe-source-han-serif-cn-fonts \
    adobe-source-han-sans-jp-fonts \
    adobe-source-han-sans-kr-fonts \
    adobe-source-han-sans-tw-fonts \
    ipa-gothic-fonts \
    ipa-mincho-fonts \
    vlgothic-fonts \
    vlgothic-p-fonts \
    2>/dev/null || true

# Indic fonts (Devanagari, Tamil, Bengali, etc.)
dnf5 install -y \
    google-noto-sans-devanagari-fonts \
    google-noto-sans-bengali-fonts \
    google-noto-sans-gujarati-fonts \
    google-noto-sans-kannada-fonts \
    google-noto-sans-malayalam-fonts \
    google-noto-sans-tamil-fonts \
    google-noto-sans-telugu-fonts \
    google-noto-sans-gurmukhi-fonts \
    google-noto-sans-oriya-fonts \
    google-noto-sans-assamese-fonts \
    google-noto-sans-sinhala-fonts \
    google-noto-sans-marathi-fonts \
    lohit-devanagari-fonts \
    lohit-tamil-fonts \
    lohit-bengali-fonts \
    lohit-gujarati-fonts \
    lohit-kannada-fonts \
    lohit-malayalam-fonts \
    lohit-punjabi-fonts \
    lohit-telugu-fonts \
    lohit-oriya-fonts \
    2>/dev/null || true

# Arabic / Hebrew / Thai / Vietnamese
dnf5 install -y \
    google-noto-sans-arabic-fonts \
    google-noto-naskh-arabic-fonts \
    google-noto-sans-hebrew-fonts \
    google-noto-sans-thai-fonts \
    google-noto-sans-vietnamese-fonts \
    2>/dev/null || true

# Emoji fonts (essential for modern messaging)
dnf5 install -y \
    google-noto-emoji-fonts \
    google-noto-color-emoji-fonts \
    twitter-twemoji-fonts \
    2>/dev/null || true

# Icon/symbol fonts
dnf5 install -y \
    google-material-design-icons-fonts \
    fontawesome-fonts \
    2>/dev/null || true

# Microsoft core fonts (Arial, Times New Roman, etc.)
# These are in RPM Fusion nonfree
dnf5 install -y \
    mscore-fonts \
    msttcore-fonts \
    2>/dev/null || echo "  MS fonts not available (need RPM Fusion nonfree)"

# ---- Font configuration (fontconfig) ----
echo "Configuring font rendering..."
mkdir -p /etc/fonts/conf.d
mkdir -p /etc/fonts/conf.avail

# Main fontconfig
cat > /etc/fonts/local.conf << 'FONTCONF'
<?xml version="1.0" encoding="UTF-8"?>
<!--
    KAAL OS Font Configuration
    Configures subpixel rendering, hinting, and font fallbacks.
-->
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>

  <!-- ==== Rendering Quality ==== -->

  <!-- Enable subpixel rendering (RGB order) -->
  <match target="font">
    <edit name="rgba" mode="assign">
      <const>rgb</const>
    </edit>
  </match>

  <!-- Enable hinting (slight = best balance of quality and speed) -->
  <match target="font">
    <edit name="hinting" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="hintstyle" mode="assign">
      <const>hintslight</const>
    </edit>
  </match>

  <!-- Enable anti-aliasing -->
  <match target="font">
    <edit name="antialias" mode="assign">
      <bool>true</bool>
    </edit>
  </match>

  <!-- Subpixel hinting (for LCD screens) -->
  <match target="font">
    <edit name="lcdfilter" mode="assign">
      <const>lcddefault</const>
    </edit>
  </match>

  <!-- Auto-hint (for fonts without native hinting) -->
  <match target="font">
    <edit name="autohint" mode="assign">
      <bool>false</bool>
    </edit>
  </match>

  <!-- ==== Font Substitution (fallbacks) ==== -->

  <!-- Default sans-serif: Inter (clean, modern) -->
  <match target="pattern">
    <test name="family">
      <string>sans-serif</string>
    </test>
    <edit name="family" mode="prepend" binding="strong">
      <string>Inter</string>
      <string>Noto Sans</string>
      <string>DejaVu Sans</string>
    </edit>
  </match>

  <!-- Default serif: Noto Serif (comprehensive Unicode coverage) -->
  <match target="pattern">
    <test name="family">
      <string>serif</string>
    </test>
    <edit name="family" mode="prepend" binding="strong">
      <string>Noto Serif</string>
      <string>DejaVu Serif</string>
    </edit>
  </match>

  <!-- Default monospace: JetBrains Mono (excellent for coding) -->
  <match target="pattern">
    <test name="family">
      <string>monospace</string>
    </test>
    <edit name="family" mode="prepend" binding="strong">
      <string>JetBrains Mono</string>
      <string>Noto Sans Mono</string>
      <string>DejaVu Sans Mono</string>
    </edit>
  </match>

  <!-- ==== Emoji Fallback ==== -->
  <!-- Always fall back to Noto Color Emoji for emoji characters -->
  <match target="pattern">
    <test name="family">
      <string>sans-serif</string>
    </test>
    <edit name="family" mode="append" binding="weak">
      <string>Noto Color Emoji</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family">
      <string>serif</string>
    </test>
    <edit name="family" mode="append" binding="weak">
      <string>Noto Color Emoji</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family">
      <string>monospace</string>
    </test>
    <edit name="family" mode="append" binding="weak">
      <string>Noto Color Emoji</string>
    </edit>
  </match>

  <!-- ==== Microsoft Font Aliases ==== -->
  <!-- Map MS fonts to open-source equivalents -->
  <match target="pattern">
    <test name="family"><string>Arial</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>Liberation Sans</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family"><string>Times New Roman</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>Liberation Serif</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family"><string>Courier New</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>Liberation Mono</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family"><string>Calibri</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>Carlito</string>
    </edit>
  </match>

  <match target="pattern">
    <test name="family"><string>Cambria</string></test>
    <edit name="family" mode="assign" binding="strong">
      <string>Caladea</string>
    </edit>
  </match>

</fontconfig>
FONTCONF

# ---- Refresh font cache ----
echo "Refreshing font cache..."
fc-cache -f 2>/dev/null || true

# ---- Verify font rendering ----
echo "Font rendering configuration:"
fc-match sans-serif 2>/dev/null || true
fc-match serif 2>/dev/null || true
fc-match monospace 2>/dev/null || true
fc-match emoji 2>/dev/null || true

echo "=== Font & Rendering Setup Complete ==="
