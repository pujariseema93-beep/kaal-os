# KAAL OS Visual Identity — Asset Specification Guide

## Overview

This document specifies every visual asset needed for KAAL OS. All assets
currently use placeholder SVGs. Replace them with your final artwork by
dropping files into the directories listed below and re-running
`install-visual-identity.sh`.

## KAAL OS Color Palette

These colors are used consistently across all themes:

| Name | Hex | Usage |
|------|-----|-------|
| Background | `#0d0d0d` | Main dark background |
| Background Alt | `#1a1a1a` | Cards, panels, input fields |
| Foreground | `#e0e0e0` | Primary text |
| Foreground Dim | `#888888` | Secondary text |
| Accent Blue | `#4A90D9` | Primary accent (buttons, selections, links) |
| Accent Blue Hover | `#5AA0E9` | Hover state |
| Accent Blue Pressed | `#3A80C9` | Active/pressed state |
| Gaming Orange | `#FF6B35` | Gaming space accent |
| Dev Blue | `#4A90D9` | Development space accent |
| Power Purple | `#9B59B6` | Power User space accent |
| Normal Green | `#2ECC71` | Normal space accent |
| Danger Red | `#c0392b` | Destructive actions |
| Success Green | `#2ECC71` | Success states |
| Warning Orange | `#FF6B35` | Warnings |
| Border | `#333333` | Borders and dividers |

---

## Asset Specifications

### 1. GRUB2 Boot Theme
**Directory:** `grub/themes/kaal/`
**Install path:** `/boot/grub2/themes/kaal/`

| File | Format | Size | Description |
|------|--------|------|-------------|
| `background.png` | PNG | 1920×1080 | Boot menu background. Dark theme, subtle KAAL branding. |
| `theme.txt` | Text | — | Already configured. Edit only if changing layout. |
| `selected_item_*.png` | PNG | Variable | Selected menu item background (optional — can use solid color). Files: `selected_item_c.png`, `selected_item_e.png`, `selected_item_w.png` |
| `menu_*.png` | PNG | Variable | Menu background frame (optional). Files: `menu_c.png`, `menu_e.png`, `menu_w.png`, `menu_n.png`, `menu_s.png`, `menu_nw.png`, `menu_ne.png`, `menu_sw.png`, `menu_se.png` |

**Notes:** GRUB uses its own rendering engine, not CSS. Background should be
PNG (not SVG). The installer converts `background.svg` to PNG automatically
if `rsvg-convert` is available, but providing a pre-made PNG is preferred.

---

### 2. Plymouth Boot Splash
**Directory:** `plymouth/themes/kaal/`
**Install path:** `/usr/share/plymouth/themes/kaal/`

| File | Format | Size | Description |
|------|--------|------|-------------|
| `logo.png` | PNG (with alpha) | 256×256 | Centered logo during boot. Transparent background. |
| `frame-01.png` through `frame-08.png` | PNG (with alpha) | 24×24 | 8-frame spinner animation shown during boot progress. Simple rotating dot. |

**Notes:** Plymouth runs before the display server, so images must be PNG.
The script uses a simple progress bar with the logo. For a more custom
animation, edit `kaal.script` (it's a bash script that calls plymouth
commands).

---

### 3. Calamares Installer Branding
**Directory:** `calamares/branding/kaal/`
**Install path:** `/usr/share/calamares/branding/kaal/`

| File | Format | Size | Description |
|------|--------|------|-------------|
| `logo.png` | PNG (with alpha) | 100×100 | Product logo in installer sidebar header. |
| `icon.png` | PNG (with alpha) | 80×80 | Product icon in installer sidebar. |
| `wallpaper.png` | PNG/JPG | 1920×1080 | Installer background. |
| `welcome.png` | PNG | 600×400 | Welcome image on first slide (optional). |

**Notes:** The slideshow (`slides.qml`) uses text-based slides, not images.
If you want image-based slides, add image paths to the QML file and provide
PNG/JPG images. The QSS (`calamares.qss`) controls all installer styling
(buttons, progress bar, inputs, etc.).

---

### 4. SDDM Login Theme (KDE)
**Directory:** `sddm/themes/kaal/`
**Install path:** `/usr/share/sddm/themes/kaal/`

| File | Format | Size | Description |
|------|--------|------|-------------|
| `background.png` | PNG/JPG | 1920×1080 | Login screen background. |

**Notes:** The login screen UI is in `Main.qml` (QML). It includes a login
panel, session selector, clock, and system buttons (reboot/shutdown). All
styling is in the QML file directly. Background should be PNG or JPG.

---

### 5. GDM Login Theme (GNOME)
**Directory:** `gdm/themes/kaal/`
**Install path:** `/usr/share/gdm/themes/kaal/`

| File | Format | Size | Description |
|------|--------|------|-------------|
| `background.png` | PNG/JPG | 1920×1080 | Login screen background. |
| `gdm.css` | CSS | — | Already configured. Edit for custom styling. |

**Notes:** GNOME's GDM uses CSS for styling. The CSS references
`background.png` via `#lockDialogGroup`. GNOME 45+ may require different
CSS selectors — test on your target version.

---

### 6. Wallpapers
**Directory:** `wallpapers/`
**Install path:** `/usr/share/backgrounds/kaal/`

| File | Format | Size | Description |
|------|--------|------|-------------|
| `default.png` | PNG/JPG | 1920×1080 | Default system wallpaper. |
| `gaming.png` | PNG/JPG | 1920×1080 | Wallpaper for Gaming Space. |
| `development.png` | PNG/JPG | 1920×1080 | Wallpaper for Development Space. |
| `power.png` | PNG/JPG | 1920×1080 | Wallpaper for Power User Space. |
| `normal.png` | PNG/JPG | 1920×1080 | Wallpaper for Normal Space. |

**Notes:** Each Kaal Space can use its own wallpaper. The `apply-space.sh`
script in the Spaces package sets the wallpaper when switching spaces.
Provide PNG or JPG at 1920×1080 (or higher resolution — the system will
scale). For 4K displays, provide 3840×2160 versions.

---

### 7. Icon Set
**Directory:** `icons/hicolor/scalable/`
**Install path:** `/usr/share/icons/hicolor/scalable/`

| File | Format | Size | Description |
|------|--------|------|-------------|
| **Apps** (`apps/`) | SVG | 128×128 | Application icons |
| `kaal-spaces.svg` | SVG | 128×128 | Main KAAL Spaces app icon |
| `kaal-space-switcher.svg` | SVG | 128×128 | Space switcher app icon |
| `kaal-space-editor.svg` | SVG | 128×128 | Space editor app icon |
| `kaal-update.svg` | SVG | 128×128 | Update manager icon |
| `kaal-installer.svg` | SVG | 128×128 | Installer icon |
| `kaal-config.svg` | SVG | 128×128 | System config icon |
| **Categories** (`categories/`) | SVG | 64×64 | Space category icons |
| `kaal-space-gaming.svg` | SVG | 64×64 | Gaming space icon |
| `kaal-space-development.svg` | SVG | 64×64 | Development space icon |
| `kaal-space-power.svg` | SVG | 64×64 | Power user space icon |
| `kaal-space-normal.svg` | SVG | 64×64 | Normal space icon |
| **Places** (`places/`) | SVG | 128×128 | Distro identity icons |
| `kaal-logo.svg` | SVG | 128×128 | KAAL OS logo (app menu, about dialog) |
| `start-here-kaal.svg` | SVG | 128×128 | Start menu / app launcher icon |

**Notes:** SVG is preferred for icons (scales to any size). If providing
PNG, include multiple sizes: 16, 24, 32, 48, 64, 128, 256. The icon set
uses the freedesktop hicolor icon theme specification.

---

### 8. GTK Theme
**Directory:** `gtk/themes/kaal/`
**Install path:** `/usr/share/themes/kaal/gtk-3.0/` and `gtk-4.0/`

| File | Format | Size | Description |
|------|--------|------|-------------|
| `gtk.css` | CSS | — | GTK3/4 application styling. Already configured. |

**Notes:** The GTK theme uses CSS with `@define-color` variables. Edit the
variables at the top of `gtk.css` to change the color scheme globally. GTK4
may need slightly different selectors — test on your target version.

---

### 9. Qt/KDE Color Scheme
**Directory:** `qt/colors/`
**Install path:** `/usr/share/color-schemes/`

| File | Format | Size | Description |
|------|--------|------|-------------|
| `kaal.colors` | INI | — | KDE color scheme. Already configured. |

**Notes:** This is a KDE-native `.colors` file (INI format). It defines
colors for all KDE UI elements (buttons, selections, tooltips, window
decorations). Edit the RGB values directly. Applied via System Settings >
Colors.

---

### 10. Cursor Theme
**Directory:** `cursors/kaal/`
**Install path:** `/usr/share/icons/kaal/`

| File | Format | Size | Description |
|------|--------|------|-------------|
| `index.theme` | INI | — | Theme metadata. Already configured. |
| Cursor files | XCursor | 24×24 | Actual cursor shapes (see below) |

**Required cursor shapes:**
`default`, `pointer`, `text`, `wait`, `crosshair`, `help`, `move`,
`n-resize`, `s-resize`, `e-resize`, `w-resize`, `ne-resize`,
`nw-resize`, `se-resize`, `sw-resize`, `not-allowed`, `vertical-text`,
`context-menu`, `copy`, `alias`, `no-drop`, `grab`, `grabbing`

**Notes:** Cursor themes use the XCursor format (binary). You need a tool
like `xcur2png` to extract or `xcursorgen` to create them. This is the
hardest asset to create — consider using an existing cursor theme
(like Breeze or Bibata) as a base and just recoloring.

---

### 11. Sound Scheme
**Directory:** `sounds/`
**Install path:** `/usr/share/sounds/kaal/`

| File | Format | Duration | Description |
|------|--------|----------|-------------|
| `login.ogg` | OGG Vorbis | < 2s | Login sound |
| `logout.ogg` | OGG Vorbis | < 2s | Logout sound |
| `boot.ogg` | OGG Vorbis | < 3s | Boot complete sound |
| `shutdown.ogg` | OGG Vorbis | < 2s | Shutdown sound |
| `space-switch.ogg` | OGG Vorbis | < 1s | Space switch notification |
| `notification.ogg` | OGG Vorbis | < 1s | General notification |
| `error.ogg` | OGG Vorbis | < 1s | Error alert |
| `warning.ogg` | OGG Vorbis | < 1s | Warning alert |
| `complete.ogg` | OGG Vorbis | < 1s | Task complete |

**Notes:** All sounds should be OGG Vorbis format. Keep them short and
subtle. The sound scheme is optional — users can disable it in settings.

---

## Quick Asset Checklist

When you're ready to provide assets, here's the minimum viable set:

### Essential (must have)
- [ ] `grub/themes/kaal/background.png` — 1920×1080 PNG
- [ ] `plymouth/themes/kaal/logo.png` — 256×256 PNG with transparency
- [ ] `calamares/branding/kaal/logo.png` — 100×100 PNG with transparency
- [ ] `calamares/branding/kaal/wallpaper.png` — 1920×1080 PNG/JPG
- [ ] `sddm/themes/kaal/background.png` — 1920×1080 PNG/JPG
- [ ] `gdm/themes/kaal/background.png` — 1920×1080 PNG/JPG
- [ ] `wallpapers/default.png` — 1920×1080 PNG/JPG

### Recommended (should have)
- [ ] `icons/hicolor/scalable/apps/kaal-spaces.svg` — 128×128 SVG
- [ ] `icons/hicolor/scalable/places/start-here-kaal.svg` — 128×128 SVG
- [ ] `wallpapers/gaming.png`, `development.png`, `power.png`, `normal.png`
- [ ] `plymouth/themes/kaal/frame-01.png` through `frame-08.png` — 24×24 PNG spinner

### Optional (nice to have)
- [ ] `calamares/branding/kaal/icon.png` — 80×80 PNG
- [ ] `calamares/branding/kaal/welcome.png` — 600×400 PNG
- [ ] Full icon set (all 14 icons as polished SVGs)
- [ ] Cursor theme (XCursor format — complex, consider using existing theme)
- [ ] Sound scheme (9 OGG files)
- [ ] GRUB PNG frame assets (selected_item_*.png, menu_*.png)

---

## Installation

After replacing placeholders with your final assets:

```bash
sudo bash scripts/install-visual-identity.sh
```

The script installs all 11 components to their correct system paths and
applies configuration. You can run it multiple times — it overwrites
previous installations.

To verify everything is installed:

```bash
# Check GRUB theme
ls /boot/grub2/themes/kaal/

# Check Plymouth
plymouth-set-default-theme

# Check wallpapers
ls /usr/share/backgrounds/kaal/

# Check icons
ls /usr/share/icons/hicolor/scalable/apps/kaal-*.svg

# Check GTK theme
ls /usr/share/themes/kaal/gtk-3.0/gtk.css

# Check Qt colors
ls /usr/share/color-schemes/kaal.colors
```

---

## File Structure

```
kaal-visual/
├── grub/
│   ├── themes/kaal/
│   │   ├── theme.txt          # GRUB theme config
│   │   └── background.svg     # Placeholder (replace with background.png)
│   └── install-grub-theme.sh  # Standalone GRUB installer
├── plymouth/
│   ├── themes/kaal/
│   │   ├── kaal.plymouth      # Plymouth module definition
│   │   ├── kaal.script        # Boot splash script
│   │   └── logo.svg           # Placeholder (replace with logo.png)
│   └── install-plymouth-theme.sh
├── calamares/
│   └── branding/kaal/
│       ├── branding.desc      # Branding configuration
│       ├── calamares.qss      # Qt style sheet for installer
│       └── slides.qml         # Installation slideshow
├── sddm/
│   └── themes/kaal/
│       ├── theme.conf         # SDDM theme config
│       └── Main.qml           # QML login screen
├── gdm/
│   ├── themes/kaal/
│   │   └── gdm.css            # GDM CSS styling
│   └── install-gdm-theme.sh
├── wallpapers/
│   ├── default.svg            # Placeholder
│   ├── gaming.svg
│   ├── development.svg
│   ├── power.svg
│   └── normal.svg
├── icons/
│   └── hicolor/scalable/
│       ├── apps/              # 6 app icons (SVG)
│       ├── categories/        # 4 space icons (SVG)
│       ├── status/            # 2 status icons (SVG)
│       └── places/            # 2 distro icons (SVG)
├── gtk/
│   └── themes/kaal/
│       └── gtk.css            # GTK3/4 theme CSS
├── qt/
│   └── colors/
│       └── kaal.colors        # KDE color scheme
├── cursors/
│   └── kaal/
│       ├── index.theme        # Cursor theme config
│       └── default.svg        # Placeholder
├── sounds/
│   ├── index.theme            # Sound theme config
│   └── sounds.conf            # Sound event mapping
├── scripts/
│   └── install-visual-identity.sh  # Master installer
└── docs/
    └── VISUAL_IDENTITY.md     # This document
```
