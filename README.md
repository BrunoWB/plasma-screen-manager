# Plasma Screen Manager

A sleek, intuitive desktop widget for **KDE Plasma 6** on Wayland (tested on Bazzite & Fedora Kinoite) providing fast, one-click multi-monitor management and presentation mode.

Designed as a modern replacement for the default KDE display widget, it puts monitor layout, primary display assignment, power toggling, and sleep inhibition directly on your desktop.

---

## Features

- **Side-by-Side Spatial Layout**: Renders connected displays horizontally ordered by their physical left-to-right desktop geometry (`pos.x`).
- **Hardware-Agnostic Device Detection**: Dynamically parses standard VESA EDID descriptor blocks (`/sys/class/drm/*/edid`) to discover device names (Samsung, LG, Dell, Epson, ASUS, BenQ, etc.) without hardcoding.
- **Primary Monitor Selector (Star)**: One-click primary display assignment (`priority 1` via `kscreen-doctor`), with active visual glow and a `PRIMARY` badge.
- **Display Output Toggle (Eye)**: Quickly turn monitors on or off on demand.
- **Safety Lockout Protection**: Built-in guard prevents disabling the only remaining active display to protect you from black-screen lockouts.
- **Presentation Mode (Keep Awake)**: Top-right toggle inhibits system sleep and screen dimming/locking via `systemd-inhibit` (ideal for gaming, media playback, presentations).
- **Smart Auto-Refresh on Hover**: Moving your mouse cursor over the widget automatically triggers a background refresh (throttled to avoid redundant queries).
- **Periodic Background Sync**: Runs every 20 seconds to detect hotplugged or disconnected displays.
- **Dedicated Vector SVG Icons**: High-contrast, clean vector assets that remain pixel-perfect regardless of the active desktop icon theme.
- **Custom Name Aliases**: Optional user-defined nicknames in `~/.config/plasma-screen-manager/aliases.json`.

---

## Requirements

- **Desktop Environment**: KDE Plasma 6.x (Wayland session)
- **Tools**: `kscreen-doctor`, `systemd-inhibit`, Python 3
- **Tested Distributions**: Bazzite (Fedora Silverblue/Kinoite 40+), Fedora 40/41/42+ KDE

---

## Installation

### 1. Clone the repository
```bash
git clone https://github.com/yourusername/plasma-screen-manager.git
cd plasma-screen-manager
```

### 2. Run the installer
```bash
./install.sh
```

### 3. Add to your desktop
1. Right-click on your desktop wallpaper.
2. Select **"Add Widgets..."** (or press `Meta` + `W`).
3. Search for **"Screen Manager"**.
4. Drag and drop it onto your desktop or panel.

---

## Manual Installation

To install without running the script, copy the repository folder into your user plasmoids directory:

```bash
mkdir -p ~/.local/share/plasma/plasmoids/
cp -r . ~/.local/share/plasma/plasmoids/org.scyan.screenmanager
kbuildsycoca6 --noincremental
```

---

## Custom Display Aliases

If you wish to override detected hardware names with custom friendly labels:

Create or edit `~/.config/plasma-screen-manager/aliases.json`:

```json
{
  "HDMI-A-2": "SAMSUNG NEO 8",
  "DP-1": "EPSON PROJECTOR"
}
```

The widget will prioritize your aliases and seamlessly fall back to EDID hardware model strings for any other attached screens.

---

## Architecture

```
plasma-screen-manager/
├── metadata.json                          # KDE Plasma 6 Applet descriptor
├── install.sh                             # Fast installation helper
├── contents/
│   ├── config/
│   │   └── main.xml                       # Plasma configuration schema
│   ├── scripts/
│   │   └── screen_ctl.py                  # Python backend (EDID parser, kscreen-doctor, DBus)
│   └── ui/
│       ├── main.qml                       # Primary widget container & top bar
│       ├── ScreenCard.qml                 # Individual monitor card component
│       ├── configGeneral.qml              # Settings configuration dialog
│       └── assets/                        # Dedicated vector SVG icons
│           ├── eye.svg
│           ├── eye-off.svg
│           ├── star-filled.svg
│           ├── star-outline.svg
│           ├── monitor.svg
│           ├── refresh.svg
│           ├── presentation.svg
│           └── presentation-active.svg
```

---

## License

MIT License. Feel free to use, modify, and distribute.
