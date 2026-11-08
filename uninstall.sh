#!/usr/bin/env bash
# ==============================================================================
# VirtualBox Control Center for KDE Plasma 6 — Uninstaller
# ==============================================================================
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

APPLET_ID="org.kde.plasma.vboxcontrolcenter"
USER_PLASMOID_DIR="${HOME}/.local/share/plasma/plasmoids/${APPLET_ID}"
DBUS_SERVICE_FILE="${HOME}/.local/share/dbus-1/services/${APPLET_ID}.service"
CONFIG_DIR="${HOME}/.config/vboxcontrolcenter"

echo -e "${CYAN}${BOLD}==> Uninstalling VirtualBox Control Center...${NC}\n"

# 1. Remove Plasmoid via kpackagetool6
if command -v kpackagetool6 >/dev/null 2>&1; then
    echo -e "Removing plasmoid package via kpackagetool6..."
    kpackagetool6 -t Plasma/Applet -r "${APPLET_ID}" 2>/dev/null || true
fi

# 2. Remove directory if left behind
if [ -d "${USER_PLASMOID_DIR}" ]; then
    echo -e "Cleaning up directory: ${USER_PLASMOID_DIR}"
    rm -rf "${USER_PLASMOID_DIR}"
fi

# 3. Remove D-Bus service file
if [ -f "${DBUS_SERVICE_FILE}" ]; then
    echo -e "Removing D-Bus service definition: ${DBUS_SERVICE_FILE}"
    rm -f "${DBUS_SERVICE_FILE}"
fi

# 4. Reload D-Bus
if systemctl --user is-active dbus-broker.service >/dev/null 2>&1; then
    systemctl --user reload dbus-broker.service 2>/dev/null || true
elif systemctl --user is-active dbus.service >/dev/null 2>&1; then
    systemctl --user reload dbus.service 2>/dev/null || true
fi

# 5. Clean up favorites config if requested
if [ -d "${CONFIG_DIR}" ]; then
    read -rp "Remove saved favorites and widget state (${CONFIG_DIR})? [y/N] " resp
    if [[ "$resp" =~ ^[Yy]$ ]]; then
        rm -rf "${CONFIG_DIR}"
        echo -e "Removed ${CONFIG_DIR}"
    fi
fi

echo -e "\n${GREEN}${BOLD}✔ Uninstallation complete.${NC}\n"
