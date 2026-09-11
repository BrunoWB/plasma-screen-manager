#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.local/share/plasma/plasmoids/org.scyan.screenmanager"

echo "Installing Screen Manager plasmoid..."
mkdir -p "${HOME}/.local/share/plasma/plasmoids"
rm -rf "${TARGET_DIR}"
cp -r "${SCRIPT_DIR}" "${TARGET_DIR}"
rm -rf "${TARGET_DIR}/.git" "${TARGET_DIR}/install.sh"

chmod +x "${TARGET_DIR}/contents/scripts/screen_ctl.py"
chmod +x "${TARGET_DIR}/contents/scripts/toggle_window.sh" 2>/dev/null || true
chmod +x "${TARGET_DIR}/contents/scripts/setup_shortcut.sh" 2>/dev/null || true
chmod +x "${TARGET_DIR}/contents/scripts/kscreen_osd_shim.py" 2>/dev/null || true

RUN_HOST=""
if [ -f /.flatpak-info ] && command -v flatpak-spawn >/dev/null 2>&1; then
    RUN_HOST="flatpak-spawn --host"
fi

echo "Rebuilding system configuration cache..."
if $RUN_HOST which kbuildsycoca6 >/dev/null 2>&1; then
    $RUN_HOST kbuildsycoca6 --noincremental
fi

echo "Restarting Plasma shell..."
$RUN_HOST systemctl --user restart plasma-plasmashell.service 2>/dev/null || true

echo "Setting up Cmd+P / Meta+P shortcut..."
"${TARGET_DIR}/contents/scripts/setup_shortcut.sh"

echo "Successfully installed to ${TARGET_DIR}!"
echo "Add it from your desktop: Right-click Desktop -> 'Add Widgets...' -> search 'Screen Manager'."
echo "Or press Cmd+P (or Meta+P) anywhere to toggle the floating Screen Manager window!"

