#!/usr/bin/env bash
set -euo pipefail

RUN_HOST=""
if [ -f /.flatpak-info ] && command -v flatpak-spawn >/dev/null 2>&1; then
    RUN_HOST="flatpak-spawn --host"
fi

PLASMAWINDOWED_BIN=""
if [[ -n "${RUN_HOST}" ]]; then
    PLASMAWINDOWED_BIN="$($RUN_HOST which plasmawindowed 2>/dev/null || $RUN_HOST which plasmawindowed6 2>/dev/null || true)"
else
    PLASMAWINDOWED_BIN="$(command -v plasmawindowed 2>/dev/null || command -v plasmawindowed6 2>/dev/null || true)"
fi

if [[ -z "${PLASMAWINDOWED_BIN}" ]]; then
    echo "Error: plasmawindowed not found on this system." >&2
    exit 1
fi

APPLET_ID="org.scyan.screenmanager"

# Check if an instance is already running
if $RUN_HOST pgrep -f "plasmawindowed.*${APPLET_ID}" >/dev/null 2>&1; then
    $RUN_HOST pkill -f "plasmawindowed.*${APPLET_ID}"
else
    # Launch detached in the background
    if [[ -n "${RUN_HOST}" ]]; then
        $RUN_HOST nohup "${PLASMAWINDOWED_BIN}" "${APPLET_ID}" >/dev/null 2>&1 &
    else
        nohup "${PLASMAWINDOWED_BIN}" "${APPLET_ID}" >/dev/null 2>&1 &
    fi
fi

