#!/bin/sh
# AiraOS Comprehensive Test Suite - covers all 1.3/1.4/1.5 features
# Run in QEMU guest to verify system functionality

set -e

TEST_DIR="/tmp/aira-test-$$"
mkdir -p "$TEST_DIR"
RESULTS="$TEST_DIR/results.log"

echo "=== AiraOS Full Test Suite ===" | tee "$RESULTS"
echo "Date: $(date)" | tee -a "$RESULTS"
echo "Kernel: $(uname -a)" | tee -a "$RESULTS"
echo

pass=0
fail=0

run_test() {
    local name="$1"
    shift
    echo "Testing: $name" | tee -a "$RESULTS"
    if "$@" >>"$RESULTS" 2>&1; then
        echo "  PASS" | tee -a "$RESULTS"
        pass=$((pass+1))
    else
        echo "  FAIL" | tee -a "$RESULTS"
        fail=$((fail+1))
    fi
}

# ===== BOOT/INIT TESTS =====
echo "=== Boot/Init Tests ===" | tee -a "$RESULTS"

run_test "initramfs mounted" mount | grep -q " / "
run_test "proc mounted" mount | grep -q " /proc "
run_test "sysfs mounted" mount | grep -q " /sys "
run_test "devtmpfs mounted" mount | grep -q " /dev "
run_test "tmpfs on /tmp" mount | grep -q " /tmp "
run_test "tmpfs on /run" mount | grep -q " /run "

# ===== SERVICE TESTS =====
echo | tee -a "$RESULTS"
echo "=== Service Tests ===" | tee -a "$RESULTS"

run_test "syslog running" /sbin/aira-init status syslog | grep -q "running"
run_test "klog running" /sbin/aira-init status klog | grep -q "running"
run_test "net oneshot done" /sbin/aira-init status net | grep -q "done"
run_test "persist oneshot done" /sbin/aira-init status persist | grep -q "done"
run_test "ipc running" /sbin/aira-init status ipc | grep -q "running"
run_test "device oneshot done" /sbin/aira-init status device | grep -q "done"
run_test "hardening oneshot done" /sbin/aira-init status hardening | grep -q "done"
run_test "recovery oneshot done" /sbin/aira-init status recovery | grep -q "done"
run_test "user-session oneshot done" /sbin/aira-init status user-session | grep -q "done"

# ===== IPC TESTS =====
echo | tee -a "$RESULTS"
echo "=== IPC Tests ===" | tee -a "$RESULTS"

run_test "IPC bus ping" aira-ipc ping test
run_test "IPC list services" aira-ipc list | grep -q "bus"
run_test "IPC system version" aira-ipc call system version | grep -q "VERSION"
run_test "IPC system info" aira-ipc call system info | grep -q "os="
run_test "IPC storage persist" aira-ipc call storage persist
run_test "IPC network interfaces" aira-ipc call network interfaces
run_test "IPC services status" aira-ipc call services status
run_test "IPC device list" aira-ipc call device list
run_test "IPC user list" aira-ipc call user list

# ===== USER/SECURITY TESTS =====
echo | tee -a "$RESULTS"
echo "=== User/Security Tests ===" | tee -a "$RESULTS"

run_test "aira-user list" aira-user list | grep -q "aira"
run_test "aira-user groups aira" aira-user groups aira
run_test "/etc/shadow exists" [ -f /etc/shadow ]
run_test "aira user in passwd" grep -q "^aira:" /etc/passwd
run_test "aira user in shadow" grep -q "^aira:" /etc/shadow
run_test "aira-hardening runs" /sbin/aira-hardening

# ===== NETWORK TESTS =====
echo | tee -a "$RESULTS"
echo "=== Network Tests ===" | tee -a "$RESULTS"

run_test "lo interface up" ip link show lo | grep -q "UP"
run_test "loopback address" ip addr show lo | grep -q "127.0.0.1"
run_test "aira-net-setup runs" /usr/bin/aira-net-setup
run_test "aira network command" aira network | grep -q "interfaces"

# ===== STORAGE TESTS =====
echo | tee -a "$RESULTS"
echo "=== Storage Tests ===" | tee -a "$RESULTS"

run_test "df works" df -h
run_test "aira storage command" aira storage | grep -q "disks"
run_test "aira-device-setup runs" /usr/bin/aira-device-setup
run_test "block devices listed" aira-ipc call device block

# ===== PACKAGE TESTS =====
echo | tee -a "$RESULTS"
echo "=== Package Tests ===" | tee -a "$RESULTS"

run_test "airapkg list" airapkg list
run_test "aira packages command" aira packages list
run_test "airapkg update-check" airapkg update-check

# ===== SYSTEM COMMAND TESTS =====
echo | tee -a "$RESULTS"
echo "=== System Command Tests ===" | tee -a "$RESULTS"

run_test "aira info" aira info | grep -q "AiraOS"
run_test "aira version" aira version | grep -q "AiraOS"
run_test "aira system" aira system | grep -q "kernel"
run_test "aira status" aira status | grep -q "mounts"
run_test "aira doctor" aira doctor
run_test "aira diagnose" aira diagnose | grep -q "DIAGNOSE"
run_test "aira platform" aira platform | grep -q "cpu"
run_test "aira info --json" aira info --json | grep -q '"os"'

# ===== RECOVERY TESTS =====
echo | tee -a "$RESULTS"
echo "=== Recovery Tests ===" | tee -a "$RESULTS"

run_test "aira-recovery check" /sbin/aira-recovery check all
run_test "aira-recovery check services" /sbin/aira-recovery check services
run_test "aira-recovery check storage" /sbin/aira-recovery check storage

# ===== UPDATE TESTS =====
echo | tee -a "$RESULTS"
echo "=== Update Tests ===" | tee -a "$RESULTS"

run_test "aira-update status" /sbin/aira-update status
run_test "aira-update check" /sbin/aira-update check || true  # may fail if no update

# ===== SDK TESTS =====
echo | tee -a "$RESULTS"
echo "=== SDK Tests ===" | tee -a "$RESULTS"

run_test "aira-sdk info" /usr/bin/aira-sdk info
run_test "aira-sdk setup" /usr/bin/aira-sdk setup

# ===== AUDIO/POWER TESTS =====
echo | tee -a "$RESULTS"
echo "=== Audio/Power Tests ===" | tee -a "$RESULTS"

run_test "aira-audio status" /usr/bin/aira-audio status
run_test "aira-power status" /usr/bin/aira-power status
run_test "aira-power acpi" /usr/bin/aira-power acpi

# ===== LOG TESTS =====
echo | tee -a "$RESULTS"
echo "=== Log Tests ===" | tee -a "$RESULTS"

run_test "aira-log list" /usr/bin/aira-log list
run_test "aira-log view syslog" /usr/bin/aira-log view syslog 10

# ===== DESKTOP/APP TESTS (if X available) =====
if [ -n "${DISPLAY:-}" ] && command -v xterm >/dev/null 2>&1; then
    echo | tee -a "$RESULTS"
    echo "=== Desktop/App Tests ===" | tee -a "$RESULTS"
    
    run_test "aira-session --help" aira-session --help
    run_test "aira-terminal --help" aira-terminal --help 2>&1 | head -1
    run_test "aira-file-manager --help" aira-file-manager --help 2>&1 | head -1
    run_test "aira-settings --help" aira-settings --help 2>&1 | head -1
    run_test "aira-sysmon --once" aira-sysmon --once | grep -q "cpu"
    run_test "aira-netman --once" aira-netman --once | grep -q "interfaces"
    run_test "aira-pkgcenter --text" aira-pkgcenter --text <<< "q" 2>&1 | head -1
    run_test "aira-textedit --help" aira-textedit --help 2>&1 | head -1
    run_test "aira-about" aira-about | grep -q "AiraOS"
    run_test "aira-sysinfo --once" aira-sysinfo --once | grep -q "AiraOS"
    run_test "aira-welcome --help" aira-welcome --help 2>&1 | head -1
    run_test "aira-help" aira-help | grep -q "MAIN COMMANDS"
    run_test "aira-notify" aira-notify test "message" 2>&1
fi

# ===== INSTALL TEST =====
echo | tee -a "$RESULTS"
echo "=== Install Test ===" | tee -a "$RESULTS"

run_test "aira-install --help" /sbin/aira-install --help

# ===== SUMMARY =====
echo | tee -a "$RESULTS"
echo "========================================" | tee -a "$RESULTS"
echo "TEST SUMMARY: $pass passed, $fail failed" | tee -a "$RESULTS"
echo "========================================" | tee -a "$RESULTS"

# Save results
cp "$RESULTS" /tmp/aira-test-results-$(date +%Y%m%d-%H%M%S).log

[ "$fail" -eq 0 ] && exit 0 || exit 1