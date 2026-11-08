#!/usr/bin/env python3
"""
VirtualBox Control Center — D-Bus Service Backend
Exposes VirtualBox VM management securely and asynchronously over D-Bus for KDE Plasma 6.
"""

import sys
import os
import re
import json
import shutil
import time
import subprocess
import threading
from pathlib import Path

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

DBUS_SERVICE_NAME = "org.kde.plasma.vboxcontrolcenter"
DBUS_OBJECT_PATH = "/VirtualBox"
DBUS_INTERFACE_NAME = "org.kde.plasma.VirtualBoxControlCenter"

CONFIG_DIR = Path.home() / ".config" / "vboxcontrolcenter"
FAVORITES_FILE = CONFIG_DIR / "favorites.json"

UUID_PATTERN = re.compile(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')


class VBoxManager:
    """Handles low-level execution of VBoxManage commands safely."""

    def __init__(self, vbm_path=None):
        self.vbm_path = vbm_path or shutil.which("VBoxManage") or "/usr/bin/VBoxManage"

    def is_installed(self):
        return bool(self.vbm_path and os.path.exists(self.vbm_path) and os.access(self.vbm_path, os.X_OK))

    def get_version(self):
        if not self.is_installed():
            return ""
        try:
            res = subprocess.run([self.vbm_path, "--version"], capture_output=True, text=True, timeout=5)
            return res.stdout.strip() if res.returncode == 0 else ""
        except Exception:
            return ""

    def list_vms(self):
        if not self.is_installed():
            return []
        try:
            res = subprocess.run([self.vbm_path, "list", "vms"], capture_output=True, text=True, timeout=10)
            if res.returncode != 0:
                return []
            return self.parse_vm_list(res.stdout)
        except Exception as e:
            sys.stderr.write(f"Error listing VMs: {e}\n")
            return []

    def list_running_vms(self):
        if not self.is_installed():
            return set()
        try:
            res = subprocess.run([self.vbm_path, "list", "runningvms"], capture_output=True, text=True, timeout=10)
            if res.returncode != 0:
                return set()
            running = self.parse_vm_list(res.stdout)
            return {uuid for _, uuid in running}
        except Exception:
            return set()

    @staticmethod
    def parse_vm_list(text):
        """Parses `VBoxManage list vms` output safely."""
        vms = []
        for line in text.splitlines():
            line = line.strip()
            if not line:
                continue
            # Regex captures "Name with any characters" {uuid}
            m = re.match(r'^"(.*)"\s+\{([0-9a-fA-F-]+)\}$', line)
            if m:
                name, uuid = m.group(1), m.group(2)
                vms.append((name, uuid))
        return vms

    def get_vm_info(self, uuid):
        if not self.is_installed() or not UUID_PATTERN.match(uuid):
            return None
        try:
            res = subprocess.run([self.vbm_path, "showvminfo", uuid, "--machinereadable"],
                                 capture_output=True, text=True, timeout=10)
            if res.returncode != 0:
                return {"uuid": uuid, "name": "Unknown", "state": "inaccessible", "error": res.stderr.strip()}
            return self.parse_vm_info(res.stdout, uuid)
        except subprocess.TimeoutExpired:
            return {"uuid": uuid, "name": "Unknown", "state": "error", "error": "Query timed out"}
        except Exception as e:
            return {"uuid": uuid, "name": "Unknown", "state": "error", "error": str(e)}

    @staticmethod
    def parse_vm_info(output, uuid):
        props = {}
        for line in output.splitlines():
            line = line.strip()
            if not line or "=" not in line:
                continue
            k, v = line.split("=", 1)
            k = k.strip()
            v = v.strip()
            if v.startswith('"') and v.endswith('"'):
                v = v[1:-1]
            props[k] = v

        name = props.get("name", "Unknown VM")
        ostype = props.get("ostype", "Other/Unknown")
        state_raw = props.get("VMState", "poweroff").lower()
        cpus = int(props.get("cpus", 1))
        memory_mb = int(props.get("memory", 1024))

        # Network mode detection (nic1, nic2...)
        nic1 = props.get("nic1", "none").lower()
        nic_label = "No Network"
        if nic1 == "nat":
            nic_label = "NAT"
        elif nic1 == "bridged":
            nic_label = f"Bridged ({props.get('bridgeadapter1', '')})".strip()
        elif nic1 == "hostonly":
            nic_label = "Host-Only"
        elif nic1 == "intnet":
            nic_label = "Internal"
        elif nic1 != "none":
            nic_label = nic1.upper()

        # Format RAM in GB if >= 1024
        ram_label = f"{memory_mb / 1024:.1f} GB".replace(".0 GB", " GB") if memory_mb >= 1024 else f"{memory_mb} MB"

        # Friendly State Label & Badge Color mapping
        state_info = VBoxManager.map_state(state_raw)

        return {
            "uuid": uuid,
            "name": name,
            "ostype": ostype,
            "osCategory": VBoxManager.detect_os_category(ostype),
            "osIcon": VBoxManager.detect_os_icon(ostype),
            "stateRaw": state_raw,
            "stateLabel": state_info["label"],
            "stateColor": state_info["color"],
            "stateCategory": state_info["category"],  # "running", "paused", "stopped", "saved", "error"
            "cpus": cpus,
            "memoryMb": memory_mb,
            "memoryLabel": ram_label,
            "network": nic_label,
            "canStart": state_raw in ["poweroff", "saved", "aborted"],
            "canPause": state_raw == "running",
            "canResume": state_raw == "paused",
            "canSave": state_raw in ["running", "paused"],
            "canShutdown": state_raw in ["running", "paused"],
            "stateChangeTime": props.get("VMStateChangeTime", "")
        }

    @staticmethod
    def map_state(state_raw):
        # Tokyo Night palette integration:
        # Running: #9ECE6A
        # Warning/Paused: #E0AF68
        # Stopped: #9AA5CE
        # Saved: #BB9AF7
        # Error/Aborted: #F7768E
        if state_raw == "running":
            return {"label": "Running", "color": "#9ECE6A", "category": "running"}
        elif state_raw == "paused":
            return {"label": "Paused", "color": "#E0AF68", "category": "paused"}
        elif state_raw == "poweroff":
            return {"label": "Powered Off", "color": "#9AA5CE", "category": "stopped"}
        elif state_raw == "saved":
            return {"label": "Saved", "color": "#BB9AF7", "category": "saved"}
        elif state_raw == "aborted":
            return {"label": "Aborted", "color": "#F7768E", "category": "stopped"}
        elif state_raw in ["stopping", "saving", "restoring"]:
            return {"label": state_raw.capitalize() + "…", "color": "#E0AF68", "category": "busy"}
        elif state_raw in ["starting"]:
            return {"label": "Starting…", "color": "#7AA2F7", "category": "busy"}
        else:
            return {"label": state_raw.capitalize(), "color": "#F7768E", "category": "error"}

    @staticmethod
    def detect_os_category(ostype):
        s = ostype.lower()
        if any(x in s for x in ["red hat", "rhel", "fedora", "centos", "rocky", "alma"]):
            return "redhat"
        elif any(x in s for x in ["ubuntu", "debian", "mint", "kali"]):
            return "debian"
        elif any(x in s for x in ["arch", "manjaro"]):
            return "arch"
        elif any(x in s for x in ["suse", "opensuse"]):
            return "suse"
        elif "linux" in s:
            return "linux"
        elif "windows" in s:
            return "windows"
        elif any(x in s for x in ["macos", "darwin", "os x"]):
            return "macos"
        elif "bsd" in s:
            return "bsd"
        return "other"

    @staticmethod
    def detect_os_icon(ostype):
        cat = VBoxManager.detect_os_category(ostype)
        icons = {
            "redhat": "distributor-logo-fedora",
            "debian": "distributor-logo-ubuntu",
            "arch": "distributor-logo-archlinux",
            "suse": "distributor-logo-opensuse",
            "linux": "utilities-terminal",
            "windows": "preferences-system-windows",
            "macos": "folder-apple",
            "bsd": "applications-other",
            "other": "computer"
        }
        return icons.get(cat, "computer")

    # Command Execution Methods
    def start_vm(self, uuid, mode="gui"):
        if not UUID_PATTERN.match(uuid):
            return False, "Invalid VM UUID format."
        m = mode if mode in ["gui", "headless", "separate"] else "gui"
        cmd = [self.vbm_path, "startvm", uuid, "--type", m]
        return self._run_command(cmd)

    def pause_vm(self, uuid):
        if not UUID_PATTERN.match(uuid):
            return False, "Invalid VM UUID format."
        cmd = [self.vbm_path, "controlvm", uuid, "pause"]
        return self._run_command(cmd)

    def resume_vm(self, uuid):
        if not UUID_PATTERN.match(uuid):
            return False, "Invalid VM UUID format."
        cmd = [self.vbm_path, "controlvm", uuid, "resume"]
        return self._run_command(cmd)

    def save_vm(self, uuid):
        if not UUID_PATTERN.match(uuid):
            return False, "Invalid VM UUID format."
        cmd = [self.vbm_path, "controlvm", uuid, "savestate"]
        return self._run_command(cmd)

    def shutdown_vm(self, uuid):
        if not UUID_PATTERN.match(uuid):
            return False, "Invalid VM UUID format."
        cmd = [self.vbm_path, "controlvm", uuid, "acpipowerbutton"]
        return self._run_command(cmd)

    def open_console(self, uuid):
        if not UUID_PATTERN.match(uuid):
            return False, "Invalid VM UUID format."
        vboxvm = shutil.which("VirtualBoxVM") or "/usr/bin/VirtualBoxVM"
        if os.path.exists(vboxvm):
            try:
                subprocess.Popen([vboxvm, "--startvm", uuid])
                return True, "Console window launched."
            except Exception as e:
                return False, f"Failed to launch VirtualBoxVM: {e}"
        # Fallback to separate startvm
        return self._run_command([self.vbm_path, "startvm", uuid, "--type", "separate"])

    def open_manager(self):
        vbox = shutil.which("VirtualBox") or "/usr/bin/VirtualBox"
        if os.path.exists(vbox):
            try:
                subprocess.Popen([vbox])
                return True, "VirtualBox Manager launched."
            except Exception as e:
                return False, f"Failed to launch VirtualBox: {e}"
        return False, "VirtualBox GUI executable not found."

    def _run_command(self, cmd):
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
            if res.returncode == 0:
                return True, res.stdout.strip() or "Operation completed successfully."
            else:
                err = res.stderr.strip() or res.stdout.strip() or "Command failed."
                return False, err
        except subprocess.TimeoutExpired:
            return False, "Operation timed out."
        except Exception as e:
            return False, str(e)


class VBoxControlCenterService(dbus.service.Object):
    """D-Bus service exposing VirtualBox control to Plasma QML widgets."""

    def __init__(self, bus_name):
        super().__init__(bus_name, DBUS_OBJECT_PATH)
        self.mgr = VBoxManager()
        self.busy_vms = set()
        self.lock = threading.Lock()
        self.cached_vms = []
        self.favorites = self.load_favorites()
        self.refresh_timer_id = None

        # Initial refresh
        self.update_vms_sync()
        # Schedule periodic background refresh every 8 seconds
        GLIB_LOOP = GLib.MainLoop()
        GLib.timeout_add_seconds(8, self.periodic_refresh)

    def load_favorites(self):
        try:
            if FAVORITES_FILE.exists():
                with open(FAVORITES_FILE, "r") as f:
                    return set(json.load(f))
        except Exception:
            pass
        return set()

    def save_favorites(self):
        try:
            CONFIG_DIR.mkdir(parents=True, exist_ok=True)
            with open(FAVORITES_FILE, "w") as f:
                json.dump(list(self.favorites), f)
        except Exception as e:
            sys.stderr.write(f"Error saving favorites: {e}\n")

    def update_vms_sync(self):
        with self.lock:
            vms_raw = self.mgr.list_vms()
            result = []
            for name, uuid in vms_raw:
                info = self.mgr.get_vm_info(uuid)
                if info:
                    info["isFavorite"] = (uuid in self.favorites)
                    info["isBusy"] = (uuid in self.busy_vms)
                    result.append(info)

            # Sort: Busy/Running first, then favorites, then alphabetical
            def sort_key(vm):
                state_prio = 0 if vm["stateCategory"] in ["running", "busy"] else 1
                fav_prio = 0 if vm.get("isFavorite") else 1
                return (state_prio, fav_prio, vm["name"].lower())

            result.sort(key=sort_key)
            self.cached_vms = result

        json_data = json.dumps(self.cached_vms)
        self.vmsUpdated(json_data)
        return json_data

    def periodic_refresh(self):
        # Refresh in worker thread to prevent GLib loop blocking
        threading.Thread(target=self.update_vms_sync, daemon=True).start()
        return True  # Keep GLib timer active

    # -------------------------------------------------------------
    # D-Bus Signals
    # -------------------------------------------------------------
    @dbus.service.signal(DBUS_INTERFACE_NAME, signature='s')
    def vmsUpdated(self, vmsJson):
        pass

    @dbus.service.signal(DBUS_INTERFACE_NAME, signature='ssbs')
    def operationFinished(self, uuid, action, success, message):
        pass

    # -------------------------------------------------------------
    # D-Bus Methods
    # -------------------------------------------------------------
    @dbus.service.method(DBUS_INTERFACE_NAME, out_signature='s')
    def GetVMs(self):
        with self.lock:
            return json.dumps(self.cached_vms)

    @dbus.service.method(DBUS_INTERFACE_NAME, out_signature='b')
    def Refresh(self):
        threading.Thread(target=self.update_vms_sync, daemon=True).start()
        return True

    @dbus.service.method(DBUS_INTERFACE_NAME, in_signature='ss', out_signature='bs')
    def StartVM(self, uuid, mode):
        return self._execute_async(uuid, "start", lambda: self.mgr.start_vm(uuid, mode))

    @dbus.service.method(DBUS_INTERFACE_NAME, in_signature='s', out_signature='bs')
    def PauseVM(self, uuid):
        return self._execute_async(uuid, "pause", lambda: self.mgr.pause_vm(uuid))

    @dbus.service.method(DBUS_INTERFACE_NAME, in_signature='s', out_signature='bs')
    def ResumeVM(self, uuid):
        return self._execute_async(uuid, "resume", lambda: self.mgr.resume_vm(uuid))

    @dbus.service.method(DBUS_INTERFACE_NAME, in_signature='s', out_signature='bs')
    def SaveStateVM(self, uuid):
        return self._execute_async(uuid, "savestate", lambda: self.mgr.save_vm(uuid))

    @dbus.service.method(DBUS_INTERFACE_NAME, in_signature='s', out_signature='bs')
    def ShutdownVM(self, uuid):
        return self._execute_async(uuid, "shutdown", lambda: self.mgr.shutdown_vm(uuid))

    @dbus.service.method(DBUS_INTERFACE_NAME, in_signature='s', out_signature='bs')
    def OpenConsole(self, uuid):
        return self.mgr.open_console(uuid)

    @dbus.service.method(DBUS_INTERFACE_NAME, out_signature='bs')
    def OpenManager(self):
        return self.mgr.open_manager()

    @dbus.service.method(DBUS_INTERFACE_NAME, in_signature='s', out_signature='b')
    def ToggleFavorite(self, uuid):
        if uuid in self.favorites:
            self.favorites.remove(uuid)
        else:
            self.favorites.add(uuid)
        self.save_favorites()
        self.update_vms_sync()
        return uuid in self.favorites

    @dbus.service.method(DBUS_INTERFACE_NAME, out_signature='as')
    def GetFavorites(self):
        return list(self.favorites)

    def _execute_async(self, uuid, action_name, action_func):
        if not UUID_PATTERN.match(uuid):
            return False, "Invalid UUID format."
        with self.lock:
            if uuid in self.busy_vms:
                return False, f"Operation already in progress for this virtual machine."
            self.busy_vms.add(uuid)

        # Notify UI immediately that machine is busy
        self.update_vms_sync()

        def worker():
            try:
                success, msg = action_func()
            except Exception as e:
                success, msg = False, str(e)
            finally:
                with self.lock:
                    self.busy_vms.discard(uuid)
                self.operationFinished(uuid, action_name, success, msg)
                # Wait briefly then update status
                time.sleep(1.0)
                self.update_vms_sync()

        threading.Thread(target=worker, daemon=True).start()
        return True, f"Request '{action_name}' submitted."


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    session_bus = dbus.SessionBus()
    name = dbus.service.BusName(DBUS_SERVICE_NAME, session_bus)
    service = VBoxControlCenterService(session_bus)
    sys.stdout.write(f"VirtualBox Control Center D-Bus service active on {DBUS_SERVICE_NAME}\n")
    sys.stdout.flush()

    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
