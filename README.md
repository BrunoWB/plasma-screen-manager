# Screen Manager for KDE Plasma 6

A sleek, intuitive desktop widget for **KDE Plasma 6** on Wayland providing fast, one-click multi-monitor management, inline display renaming, and presentation mode.

Designed as a modern, productive replacement for standard display applets, it brings monitor layout control, primary display assignment, power toggling, sleep inhibition, and custom screen nicknames right to your desktop.

---

## Screenshots

<div align="center">

### Overview & Spatial Layout
![Screen Manager Overview](docs/screenshots/overview.png)

<br/>

| Inline Display Renaming | Primary Display & Quick Controls |
| :---: | :---: |
| ![Inline Renaming](docs/screenshots/inline-rename.png) | ![Quick Controls](docs/screenshots/quick-controls.png) |
| *Click any screen label to edit friendly names, or click **X** to reset* | *One-click primary monitor toggle, sleep inhibitor, and display power* |

</div>

---

## Features

- 🖥️ **Side-by-Side Spatial Layout**: Renders connected displays horizontally ordered by their physical desktop coordinates (`pos.x`).
- ✏️ **Inline Screen Renaming**: Hover over any monitor label to reveal the text cursor (`I-beam`), click to edit custom nicknames inline, and press <kbd>Enter</kbd> to save.
- 🔄 **One-Click Reset to Default (X)**: A smooth hover-reveal **X** button lets you instantly revert any custom nickname back to the clean hardware default name.
- 🏷️ **Dynamic Hardware & Linux PnP DB Detection**: Dynamically parses standard VESA EDID blocks (`/sys/class/drm/*/edid`) and resolves vendor names via the Linux hardware database (`/usr/share/hwdata/pnp.ids`) with clean model name extraction and fallback.
- ⭐ **Primary Monitor Selector (Star)**: Assign the primary display with a single click (`priority 1` via `kscreen-doctor`), highlighted with an active cyan border, ambient glow, and a `PRIMARY` badge.
- 👁️ **Display Output Power Toggle (Eye)**: Quickly turn external displays or projectors on or off on demand.
- 🛡️ **Blackout Safety Protection**: Built-in guard prevents turning off the only remaining active display, protecting you from accidental black-screen lockouts.
- ☕ **Presentation Mode (Keep Awake)**: Top bar toggle inhibits system idle sleep, screen dimming, and lock screen timeouts via `systemd-inhibit` (ideal for gaming, movie playback, or presentations).
- ⚡ **Non-Intrusive Background Sync**: 30-second periodic background polling automatically discovers hotplugged displays without dimming or interrupting user interactions.
- 🎨 **Pixel-Perfect Vector Graphics**: Custom inline SVG icons and smooth state transitions that integrate seamlessly with Plasma dark and light color schemes.

---

## Requirements

- **Desktop Environment**: KDE Plasma 6.x (Wayland session)
- **Dependencies**:
  - `kscreen-doctor` (included with KDE Plasma / KScreen)
  - `systemd-inhibit` (standard on systemd-based Linux systems)
  - Python 3.8+
- **Tested On**:
  - Bazzite (Fedora Silverblue / Atomic Desktop)
  - Fedora 40 / 41 / 42 (KDE Spin)
  - Arch Linux / openSUSE Tumbleweed (KDE Plasma 6)

---

## Installation

### Method 1: Automated Script (Recommended)

Clone the repository and run the installation script:

```bash
git clone https://github.com/BrunoWB/plasma-screen-manager.git
cd plasma-screen-manager
./install.sh
```

The script automatically:
1. Installs the plasmoid to `~/.local/share/plasma/plasmoids/org.scyan.screenmanager/`
2. Updates the system configuration cache (`kbuildsycoca6`)
3. Restarts the Plasma shell to load the new code immediately (with Flatpak/container detection support)

### Method 2: Download Pre-Built `.plasmoid`

1. Grab the latest `org.scyan.screenmanager-v*.plasmoid` package from the [Releases](../../releases) page.
2. Install via command-line:
   ```bash
   kpackagetool6 --type Plasma/Applet --install org.scyan.screenmanager-v*.plasmoid
   ```
   *Or install through the Plasma GUI:*
   - Right-click Desktop $\rightarrow$ **Add Widgets...** $\rightarrow$ **Get New Widgets** $\rightarrow$ **Install from Local File...** and select the `.plasmoid` file.

---

## Adding the Widget to Your Desktop

1. Right-click on your desktop wallpaper (or panel).
2. Select **"Add Widgets..."** (or press <kbd>Meta</kbd> + <kbd>W</kbd>).
3. Search for **"Screen Manager"**.
4. Drag and drop the widget onto your desktop or into your Plasma panel.

---

## Custom Display Aliases (Persistent Config)

Renaming displays via the widget saves persistent nicknames in:
```
~/.config/plasma-screen-manager/aliases.json
```

Example format:
```json
{
  "HDMI-A-2": "Odyssey G8",
  "DP-1": "Epson EB-810"
}
```

You can edit this file manually if desired, or manage your labels entirely through the widget's inline editor.

---

## Project Structure

```
plasma-screen-manager/
├── metadata.json                          # KDE Plasma 6 Applet descriptor & metadata
├── install.sh                             # Development & user install script
├── LICENSE                                # MIT License
├── README.md                              # Documentation & screenshots
├── docs/
│   └── screenshots/                       # High-resolution UI screenshots
├── contents/
│   ├── config/
│   │   └── main.xml                       # Plasmoid configuration schema
│   ├── scripts/
│   │   └── screen_ctl.py                  # Python backend (EDID parser, PnP DB, kscreen-doctor)
│   └── ui/
│       ├── main.qml                       # Top bar, periodic timers, command runner
│       ├── ScreenCard.qml                 # Screen monitor card, inline rename, controls
│       ├── configGeneral.qml              # Settings dialog
│       └── assets/                        # Dedicated vector SVG icons
│           ├── clear.svg
│           ├── eye.svg
│           ├── eye-off.svg
│           ├── monitor.svg
│           ├── presentation.svg
│           ├── presentation-active.svg
│           ├── refresh.svg
│           ├── star-filled.svg
│           └── star-outline.svg
```

---

## Contributing

Pull requests, issues, and feature suggestions are warmly welcome!
If you find a bug or have a suggestion, feel free to open an issue.

---

## License

This project is licensed under the [MIT License](LICENSE).
