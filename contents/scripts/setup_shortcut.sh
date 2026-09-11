#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLED_TARGET="${HOME}/.local/share/plasma/plasmoids/org.scyan.screenmanager/contents/scripts/toggle_window.sh"

# Determine target toggle script location
if [[ -f "${INSTALLED_TARGET}" ]]; then
    TOGGLE_PATH="${INSTALLED_TARGET}"
else
    TOGGLE_PATH="${SCRIPT_DIR}/toggle_window.sh"
fi

chmod +x "${TOGGLE_PATH}"

RUN_HOST=""
if [ -f /.flatpak-info ] && command -v flatpak-spawn >/dev/null 2>&1; then
    RUN_HOST="flatpak-spawn --host"
fi

# KDE Plasma 6 looks in ~/.local/share/applications for custom command shortcut desktop entries
APPLICATIONS_DIR="${HOME}/.local/share/applications"
KGLOBALACCEL_DIR="${HOME}/.local/share/kglobalaccel"

mkdir -p "${APPLICATIONS_DIR}" "${KGLOBALACCEL_DIR}"

DESKTOP_CONTENT="[Desktop Entry]
Comment=Toggle Screen Manager floating window
Exec=${TOGGLE_PATH}
Icon=preferences-desktop-display
Name=Toggle Screen Manager
NoDisplay=true
StartupNotify=false
Terminal=false
Type=Application
X-KDE-GlobalAccel-CommandShortcut=true"

echo "Registering custom shortcut action..."
echo "${DESKTOP_CONTENT}" > "${APPLICATIONS_DIR}/org.scyan.screenmanager.toggle.desktop"
echo "${DESKTOP_CONTENT}" > "${KGLOBALACCEL_DIR}/org.scyan.screenmanager.toggle.desktop"

echo "Configuring KDE shortcut to Meta+P (Cmd+P)..."
KWRITECONFIG=""
if [[ -n "${RUN_HOST}" ]]; then
    KWRITECONFIG="$($RUN_HOST which kwriteconfig6 2>/dev/null || $RUN_HOST which kwriteconfig5 2>/dev/null || true)"
else
    KWRITECONFIG="$(command -v kwriteconfig6 2>/dev/null || command -v kwriteconfig5 2>/dev/null || true)"
fi

if [[ -n "${KWRITECONFIG}" ]]; then
    # Unbind default Switch Display in kscreen (KDE 5 & KDE 6)
    $RUN_HOST "${KWRITECONFIG}" --file kglobalshortcutsrc --group "kscreen" --key "Switch Display" "none,Meta+P,Switch Display"
    $RUN_HOST "${KWRITECONFIG}" --file kglobalshortcutsrc --group "services" --group "org.kde.kscreen.desktop" --key "ShowOSD" "none"
    
    # Assign Meta+P to Screen Manager toggle (KDE 5 & KDE 6 services format)
    $RUN_HOST "${KWRITECONFIG}" --file kglobalshortcutsrc --group "org.scyan.screenmanager.toggle.desktop" --key "_k_friendly_name" "Toggle Screen Manager"
    $RUN_HOST "${KWRITECONFIG}" --file kglobalshortcutsrc --group "org.scyan.screenmanager.toggle.desktop" --key "_launch" "Meta+P\tDisplay,none,Toggle Screen Manager"
    $RUN_HOST "${KWRITECONFIG}" --file kglobalshortcutsrc --group "services" --group "org.scyan.screenmanager.toggle.desktop" --key "_k_friendly_name" "Toggle Screen Manager"
    $RUN_HOST "${KWRITECONFIG}" --file kglobalshortcutsrc --group "services" --group "org.scyan.screenmanager.toggle.desktop" --key "_launch" "Meta+P\tDisplay,none,Toggle Screen Manager"

    # Rebuild system configuration cache
    if [[ -n "${RUN_HOST}" ]]; then
        if $RUN_HOST which kbuildsycoca6 >/dev/null 2>&1; then
            $RUN_HOST kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
        fi
    else
        if command -v kbuildsycoca6 >/dev/null 2>&1; then
            kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
        fi
    fi

    # Configure KWin Window Rules: frameless overlay, keep above, hide from taskbar/switcher
    echo "Configuring KWin Window Rules for borderless overlay..."
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "General" --key "rules" "screenmanager_overlay"
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "Description" "Screen Manager Overlay"
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "wmclass" "plasmawindowed"
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "wmclassmatch" 2
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "title" "Screen Manager"
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "titlematch" 2
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "noborder" "true"
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "noborderrule" 2
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "above" "true"
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "aboverule" 2
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "skiptaskbar" "true"
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "skiptaskbarrule" 2
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "skipswitcher" "true"
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "skipswitcherrule" 2
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "skippager" "true"
    $RUN_HOST "${KWRITECONFIG}" --file kwinrulesrc --group "screenmanager_overlay" --key "skippagerrule" 2
fi


# Deploy systemd & dbus overrides for org.kde.kscreen.osdService
# This replaces KDE's default Display Switcher OSD at the DBus level
SHIM_PATH="${HOME}/.local/share/plasma/plasmoids/org.scyan.screenmanager/contents/scripts/kscreen_osd_shim.py"
if [[ ! -f "${SHIM_PATH}" ]]; then
    SHIM_PATH="${SCRIPT_DIR}/kscreen_osd_shim.py"
fi
chmod +x "${SHIM_PATH}"

SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
DBUS_USER_DIR="${HOME}/.local/share/dbus-1/services"
mkdir -p "${SYSTEMD_USER_DIR}" "${DBUS_USER_DIR}"

echo "Installing Screen Manager OSD D-Bus override..."
cat << EOF > "${SYSTEMD_USER_DIR}/plasma-kscreen-osd.service"
[Unit]
Description=Screen Manager OSD service (replaces KScreen OSD)
PartOf=graphical-session.target

[Service]
ExecStart=/usr/bin/python3 ${SHIM_PATH}
Type=dbus
BusName=org.kde.kscreen.osdService
TimeoutSec=10sec
Slice=background.slice
Restart=on-failure
RestartSec=1sec
EOF

cat << EOF > "${DBUS_USER_DIR}/org.kde.kscreen.osdService.service"
[D-BUS Service]
Name=org.kde.kscreen.osdService
Exec=/usr/bin/python3 ${SHIM_PATH}
SystemdService=plasma-kscreen-osd.service
EOF

# Reload systemd and restart the OSD service to activate shim
if [[ -n "${RUN_HOST}" ]]; then
    $RUN_HOST systemctl --user daemon-reload >/dev/null 2>&1 || true
    $RUN_HOST systemctl --user restart plasma-kscreen-osd.service >/dev/null 2>&1 || true
else
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user restart plasma-kscreen-osd.service >/dev/null 2>&1 || true
fi

# Ensure org.kde.kscreen.desktop ShowOSD is bound to Meta+P and Display key
GDBUS=""
if [[ -n "${RUN_HOST}" ]]; then
    GDBUS="$($RUN_HOST which gdbus 2>/dev/null || true)"
else
    GDBUS="$(command -v gdbus 2>/dev/null || true)"
fi

if [[ -n "${GDBUS}" ]]; then
    $RUN_HOST "${GDBUS}" call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.setShortcutKeys \
        "['org.kde.kscreen.desktop', 'ShowOSD', 'Display Configuration', 'Switch Display']" \
        "[([268435536, 0, 0, 0],), ([16777425, 0, 0, 0],)]" 4 >/dev/null 2>&1 || true
fi

echo "Shortcut Meta+P (Cmd+P) successfully mapped to Screen Manager!"

echo ""
echo "Setup complete! Press Cmd+P (or Meta+P) to toggle Screen Manager."
echo "You can manage this shortcut anytime in System Settings -> Shortcuts -> 'Toggle Screen Manager'."
