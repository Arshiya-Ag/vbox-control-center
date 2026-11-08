#!/usr/bin/env bash
# ==============================================================================
# VirtualBox Control Center for KDE Plasma 6 — Installer
# ==============================================================================
set -euo pipefail

# ANSI Color Codes
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${CYAN}${BOLD}==> Installing VirtualBox Control Center Plasmoid for KDE Plasma 6...${NC}\n"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLET_ID="org.kde.plasma.vboxcontrolcenter"
USER_PLASMOID_DIR="${HOME}/.local/share/plasma/plasmoids/${APPLET_ID}"
USER_DBUS_DIR="${HOME}/.local/share/dbus-1/services"
DBUS_SERVICE_FILE="${USER_DBUS_DIR}/${APPLET_ID}.service"

# 1. Dependency Checks
echo -e "${CYAN}[1/5] Checking dependencies...${NC}"

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "  [✔] Found: $1"
    else
        echo -e "  ${YELLOW}[!] Warning: '$1' not found in PATH.${NC}"
        return 1
    fi
}

check_vbox() {
    if command -v VBoxManage >/dev/null 2>&1 || [ -e "/usr/bin/VBoxManage" ] || [ -e "/opt/VirtualBox/VBoxManage" ]; then
        echo -e "  [✔] Found: VirtualBox CLI (VBoxManage)"
        return 0
    else
        echo -e "  ${YELLOW}[!] Warning: 'VBoxManage' not found in PATH.${NC}"
        echo -e "      VirtualBox does not appear to be installed in standard paths."
        return 1
    fi
}

check_cmd kpackagetool6 || echo -e "      ${YELLOW}Install 'kpackagetool6' or 'plasma-workspace' via your package manager.${NC}"
check_cmd python3 || echo -e "      ${RED}Python 3 is required.${NC}"
check_vbox || true

# Check Python D-Bus bindings
if python3 -c "import dbus, gi" 2>/dev/null; then
    echo -e "  [✔] Python D-Bus & GObject libraries present"
else
    echo -e "  ${YELLOW}[!] Python D-Bus modules not found.${NC}"
    echo -e "      Fedora:  sudo dnf install python3-dbus python3-gobject"
    echo -e "      Ubuntu:  sudo apt install python3-dbus python3-gi"
    echo -e "      Arch:    sudo pacman -S python-dbus python-gobject"
fi

# 2. Install / Upgrade Plasmoid
echo -e "\n${CYAN}[2/5] Installing Plasmoid package via kpackagetool6...${NC}"
mkdir -p "${HOME}/.local/share/plasma/plasmoids"

if kpackagetool6 -t Plasma/Applet -l | grep -q "${APPLET_ID}"; then
    echo -e "  Existing installation detected. Upgrading..."
    kpackagetool6 -t Plasma/Applet -u "${SCRIPT_DIR}" || {
        echo -e "  Upgrade returned non-zero, syncing files directly..."
        rm -rf "${USER_PLASMOID_DIR}"
        cp -r "${SCRIPT_DIR}" "${USER_PLASMOID_DIR}"
    }
else
    echo -e "  Performing clean install..."
    kpackagetool6 -t Plasma/Applet -i "${SCRIPT_DIR}" || {
        echo -e "  Fallback to direct copy..."
        rm -rf "${USER_PLASMOID_DIR}"
        cp -r "${SCRIPT_DIR}" "${USER_PLASMOID_DIR}"
    }
fi
echo -e "  ${GREEN}[✔] Plasmoid files installed in ${USER_PLASMOID_DIR}${NC}"

# 3. Register D-Bus Service
echo -e "\n${CYAN}[3/5] Registering D-Bus Service for on-demand auto-activation...${NC}"
mkdir -p "${USER_DBUS_DIR}"

PYTHON_PATH="$(command -v python3 || echo "/usr/bin/python3")"
BACKEND_SCRIPT="${USER_PLASMOID_DIR}/contents/backend/vbox_service.py"

cat <<EOF > "${DBUS_SERVICE_FILE}"
[D-BUS Service]
Name=${APPLET_ID}
Exec=${PYTHON_PATH} ${BACKEND_SCRIPT}
EOF

chmod +x "${BACKEND_SCRIPT}" 2>/dev/null || true
echo -e "  ${GREEN}[✔] Registered ${DBUS_SERVICE_FILE}${NC}"

# 4. Reload D-Bus Broker / Daemon
echo -e "\n${CYAN}[4/5] Reloading user D-Bus broker...${NC}"
if systemctl --user is-active dbus-broker.service >/dev/null 2>&1; then
    systemctl --user reload dbus-broker.service
    echo -e "  ${GREEN}[✔] Reloaded dbus-broker.service${NC}"
elif systemctl --user is-active dbus.service >/dev/null 2>&1; then
    systemctl --user reload dbus.service
    echo -e "  ${GREEN}[✔] Reloaded dbus.service${NC}"
else
    echo -e "  ${YELLOW}[!] Neither dbus-broker nor dbus user service active; on-demand activation ready.${NC}"
fi

# 5. Quick Verification
echo -e "\n${CYAN}[5/5] Testing backend communication...${NC}"
if python3 -c "
import dbus
bus = dbus.SessionBus()
proxy = bus.get_object('${APPLET_ID}', '/VirtualBox')
iface = dbus.Interface(proxy, 'org.kde.plasma.VirtualBoxControlCenter')
info = iface.GetStatus()
print(f'Connected successfully! VirtualBox version: {info.get(\"vbox_version\", \"Unknown\")}')
" 2>/dev/null; then
    echo -e "  ${GREEN}[✔] D-Bus backend service responded successfully!${NC}"
else
    echo -e "  ${YELLOW}[!] D-Bus service will activate when the widget is opened.${NC}"
fi

echo -e "\n${GREEN}${BOLD}✨ Installation complete!${NC}"
echo -e "You can now add '${BOLD}VirtualBox Control Center${NC}' to your KDE desktop:"
echo -e "  1. Right-click your desktop wallpaper -> ${CYAN}Add Widgets...${NC}"
echo -e "  2. Search for ${CYAN}VirtualBox Control Center${NC} and drag it onto your screen."
echo -e "\nOr test it immediately in a standalone preview window:"
echo -e "  ${CYAN}plasmawindowed ${APPLET_ID}${NC}\n"
