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

echo "Rebuilding system configuration cache..."
if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental
fi

echo "Refreshing Plasma shell..."
if command -v qdbus-qt6 >/dev/null 2>&1; then
    qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null || true
fi

echo "Successfully installed to ${TARGET_DIR}!"
echo "Add it from your desktop: Right-click Desktop -> 'Add Widgets...' -> search 'Screen Manager'."
