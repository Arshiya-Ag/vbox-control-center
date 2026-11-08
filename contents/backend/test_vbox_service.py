#!/usr/bin/env python3
"""
Unit tests for VirtualBox Control Center backend logic.
Verifies parsing, state mapping, UUID validation, and error handling with mocked outputs.
"""

import unittest
from vbox_service import VBoxManager, UUID_PATTERN

class TestVBoxService(unittest.TestCase):

    def test_uuid_validation(self):
        valid = "05e5fda9-837f-48d8-ac39-25f28b1f7c6a"
        invalid1 = "05e5fda9-837f-48d8-ac39-25f28b1f7c6a; rm -rf /"
        invalid2 = "../etc/passwd"
        invalid3 = "not-a-uuid"

        self.assertTrue(bool(UUID_PATTERN.match(valid)))
        self.assertFalse(bool(UUID_PATTERN.match(invalid1)))
        self.assertFalse(bool(UUID_PATTERN.match(invalid2)))
        self.assertFalse(bool(UUID_PATTERN.match(invalid3)))

    def test_parse_vm_list_standard(self):
        sample = """
"ns1.nova.test" {05e5fda9-837f-48d8-ac39-25f28b1f7c6a}
"client.nova.test" {8d3acd9e-f95d-4899-88b8-02053bed86dc}
"www.nova.test" {eaa54697-21d7-4d56-960c-5cf7dd0bfcfd}
"nginx.nova.test" {af39e5e9-bb5c-4b01-97d3-2f10e307a704}
"""
        vms = VBoxManager.parse_vm_list(sample)
        self.assertEqual(len(vms), 4)
        self.assertEqual(vms[0], ("ns1.nova.test", "05e5fda9-837f-48d8-ac39-25f28b1f7c6a"))
        self.assertEqual(vms[3], ("nginx.nova.test", "af39e5e9-bb5c-4b01-97d3-2f10e307a704"))

    def test_parse_vm_list_complex_names(self):
        sample = """
"Rocky Linux 9 (DevOps Lab) - Primary" {11111111-2222-3333-4444-555555555555}
"Kubernetes Master [v1.30] #1" {22222222-3333-4444-5555-666666666666}
"محیط تست دبیان" {33333333-4444-5555-6666-777777777777}
"VM with \"nested quotes\" inside" {44444444-5555-6666-7777-888888888888}
"""
        vms = VBoxManager.parse_vm_list(sample)
        self.assertEqual(len(vms), 4)
        self.assertEqual(vms[0][0], "Rocky Linux 9 (DevOps Lab) - Primary")
        self.assertEqual(vms[1][0], "Kubernetes Master [v1.30] #1")
        self.assertEqual(vms[2][0], "محیط تست دبیان")
        self.assertEqual(vms[3][0], 'VM with "nested quotes" inside')

    def test_parse_vm_info_running(self):
        sample_info = """
name="Rocky Linux Lab"
ostype="Red Hat (64-bit)"
UUID="05e5fda9-837f-48d8-ac39-25f28b1f7c6a"
memory=4096
cpus=4
VMState="running"
nic1="nat"
nic2="hostonly"
bridgeadapter1=""
"""
        info = VBoxManager.parse_vm_info(sample_info, "05e5fda9-837f-48d8-ac39-25f28b1f7c6a")
        self.assertEqual(info["name"], "Rocky Linux Lab")
        self.assertEqual(info["ostype"], "Red Hat (64-bit)")
        self.assertEqual(info["osCategory"], "redhat")
        self.assertEqual(info["stateRaw"], "running")
        self.assertEqual(info["stateLabel"], "Running")
        self.assertEqual(info["stateColor"], "#9ECE6A")
        self.assertEqual(info["cpus"], 4)
        self.assertEqual(info["memoryMb"], 4096)
        self.assertEqual(info["memoryLabel"], "4 GB")
        self.assertEqual(info["network"], "NAT")
        self.assertFalse(info["canStart"])
        self.assertTrue(info["canPause"])
        self.assertTrue(info["canSave"])
        self.assertTrue(info["canShutdown"])

    def test_parse_vm_info_paused(self):
        sample_info = """
name="Test Server"
ostype="Ubuntu (64-bit)"
UUID="8d3acd9e-f95d-4899-88b8-02053bed86dc"
memory=2048
cpus=2
VMState="paused"
nic1="bridged"
bridgeadapter1="enp61s0"
"""
        info = VBoxManager.parse_vm_info(sample_info, "8d3acd9e-f95d-4899-88b8-02053bed86dc")
        self.assertEqual(info["stateRaw"], "paused")
        self.assertEqual(info["stateLabel"], "Paused")
        self.assertEqual(info["stateColor"], "#E0AF68")
        self.assertTrue(info["canResume"])
        self.assertFalse(info["canPause"])
        self.assertTrue(info["canSave"])

    def test_parse_vm_info_poweroff(self):
        sample_info = """
name="Debian Box"
ostype="Debian (64-bit)"
UUID="af39e5e9-bb5c-4b01-97d3-2f10e307a704"
memory=1024
cpus=1
VMState="poweroff"
nic1="nat"
"""
        info = VBoxManager.parse_vm_info(sample_info, "af39e5e9-bb5c-4b01-97d3-2f10e307a704")
        self.assertEqual(info["stateRaw"], "poweroff")
        self.assertEqual(info["stateLabel"], "Powered Off")
        self.assertEqual(info["stateColor"], "#9AA5CE")
        self.assertTrue(info["canStart"])
        self.assertFalse(info["canPause"])
        self.assertFalse(info["canShutdown"])

    def test_parse_vm_info_aborted(self):
        sample_info = """
name="Crashed VM"
ostype="Fedora (64-bit)"
UUID="eaa54697-21d7-4d56-960c-5cf7dd0bfcfd"
memory=512
cpus=1
VMState="aborted"
nic1="none"
"""
        info = VBoxManager.parse_vm_info(sample_info, "eaa54697-21d7-4d56-960c-5cf7dd0bfcfd")
        self.assertEqual(info["stateRaw"], "aborted")
        self.assertEqual(info["stateLabel"], "Aborted")
        self.assertEqual(info["stateColor"], "#F7768E")
        self.assertEqual(info["memoryLabel"], "512 MB")
        self.assertEqual(info["network"], "No Network")
        self.assertTrue(info["canStart"])

    def test_os_category_detection(self):
        self.assertEqual(VBoxManager.detect_os_category("Red Hat (64-bit)"), "redhat")
        self.assertEqual(VBoxManager.detect_os_category("Ubuntu (64-bit)"), "debian")
        self.assertEqual(VBoxManager.detect_os_category("Arch Linux (64-bit)"), "arch")
        self.assertEqual(VBoxManager.detect_os_category("openSUSE (64-bit)"), "suse")
        self.assertEqual(VBoxManager.detect_os_category("Windows 11 (64-bit)"), "windows")
        self.assertEqual(VBoxManager.detect_os_category("macOS (64-bit)"), "macos")
        self.assertEqual(VBoxManager.detect_os_category("FreeBSD (64-bit)"), "bsd")
        self.assertEqual(VBoxManager.detect_os_category("Solaris 11 (64-bit)"), "other")

if __name__ == "__main__":
    unittest.main()
