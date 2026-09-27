#!/bin/sh
# AiraOS 1.3/1.4 Feature Verification Test
# Tests all major features implemented in releases 1.3 and 1.4

set -e

ROOT="/home/manan/Aira-Octave"

echo "========================================"
echo "AiraOS 1.3/1.4 Feature Verification"
echo "========================================"
echo

PASS=0
FAIL=0

test_file() {
    local name="$1"
    local path="$2"
    echo "Testing: $name"
    if [ -f "$ROOT/$path" ]; then
        echo "  PASS"
        PASS=$((PASS+1))
    else
        echo "  FAIL (missing: $path)"
        FAIL=$((FAIL+1))
    fi
}

test_dir() {
    local name="$1"
    local path="$2"
    echo "Testing: $name"
    if [ -d "$ROOT/$path" ]; then
        echo "  PASS"
        PASS=$((PASS+1))
    else
        echo "  FAIL (missing: $path)"
        FAIL=$((FAIL+1))
    fi
}

test_exec() {
    local name="$1"
    local path="$2"
    echo "Testing: $name"
    if [ -x "$ROOT/$path" ]; then
        echo "  PASS"
        PASS=$((PASS+1))
    else
        echo "  FAIL (missing or not executable: $path)"
        FAIL=$((FAIL+1))
    fi
}

# 1.3 Desktop Features
echo "--- 1.3 Desktop Features ---"

test_exec "aira-session" "gui/aira-session"
test_exec "aira-terminal" "gui/aira-terminal"
test_exec "aira-file-manager" "gui/aira-file-manager"
test_exec "aira-settings" "gui/aira-settings"
test_exec "aira-sysmon" "gui/aira-sysmon"
test_exec "aira-netman" "gui/aira-netman"
test_exec "aira-pkgcenter" "gui/aira-pkgcenter"
test_exec "aira-textedit" "gui/aira-textedit"
test_exec "aira-about" "gui/aira-about"
test_exec "aira-clock" "gui/aira-clock"
test_exec "aira-net-indicator" "gui/aira-net-indicator"
test_exec "aira-storage-indicator" "gui/aira-storage-indicator"
test_exec "aira-welcome" "gui/aira-welcome"
test_exec "aira-help" "gui/aira-help"
test_exec "aira-notify" "gui/aira-notify"
test_exec "aira-notifyd" "gui/aira-notifyd"
test_exec "aira-session-mgr" "gui/aira-session-mgr"
test_exec "aira-dm" "gui/aira-dm"
test_file "JWM config" "gui/aira-jwmrc"

# 1.4 User/Security Features
echo
echo "--- 1.4 User/Security Features ---"

test_exec "aira-user" "initramfs/usr/bin/aira-user"
test_exec "aira-getty" "initramfs/sbin/aira-getty"
test_exec "aira-hardening" "initramfs/sbin/aira-hardening"
test_exec "aira-recovery" "initramfs/sbin/aira-recovery"
test_exec "aira-install" "initramfs/sbin/aira-install"
test_exec "aira-update" "initramfs/sbin/aira-update"
test_exec "aira-sdk" "initramfs/usr/bin/aira-sdk"
test_exec "aira-audio" "initramfs/usr/bin/aira-audio"
test_exec "aira-power" "initramfs/usr/bin/aira-power"
test_exec "aira-log" "initramfs/usr/bin/aira-log"
test_exec "aira-info" "initramfs/usr/bin/aira-info"
test_file "/etc/shadow" "initramfs/etc/shadow"

# Service Manager Features
echo
echo "--- Service Manager Features ---"

test_exec "aira-init" "initramfs/sbin/aira-init"
test_dir "Service logs dir" "initramfs/var/log/airaos"
test_dir "Service run dir" "initramfs/run/aira-services"

# IPC Features
echo
echo "--- IPC Features ---"

test_exec "aira-ipc" "initramfs/usr/bin/aira-ipc"
test_exec "aira-ipcd" "initramfs/sbin/aira-ipcd"
test_exec "aira-ipc-handle" "initramfs/sbin/aira-ipc-handle"
test_dir "IPC handlers dir" "initramfs/etc/aira/ipc/handlers"
test_exec "bus handler" "initramfs/etc/aira/ipc/handlers/bus"
test_exec "system handler" "initramfs/etc/aira/ipc/handlers/system"
test_exec "storage handler" "initramfs/etc/aira/ipc/handlers/storage"
test_exec "network handler" "initramfs/etc/aira/ipc/handlers/network"
test_exec "services handler" "initramfs/etc/aira/ipc/handlers/services"
test_exec "device handler" "initramfs/etc/aira/ipc/handlers/device"
test_exec "user handler" "initramfs/etc/aira/ipc/handlers/user"

# Device Management
echo
echo "--- Device Management ---"

test_exec "aira-device-setup" "initramfs/usr/bin/aira-device-setup"

# Package Manager
echo
echo "--- Package Manager ---"

test_exec "airapkg" "initramfs/usr/bin/airapkg"
test_dir "Package DB dir" "initramfs/var/lib/airapkg/installed"
test_dir "Package repo dir" "initramfs/var/lib/airapkg/repo"

# Core System
echo
echo "--- Core System ---"

test_file "Kernel config" "configs/airaos-octave-x86_64.config"
test_exec "Initramfs init" "initramfs/init"
test_exec "BusyBox" "initramfs/bin/busybox"

# Summary
echo
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1