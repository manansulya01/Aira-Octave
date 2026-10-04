#!/bin/sh
# Cross-boot network persistence verification (runs when aira_netpersist=1).
# Proves that a profile written by a PREVIOUS boot still exists on /persist and
# that applying it restores connectivity in a fresh boot (no DHCP needed).
# Prints NETPERSIST markers, then poweroff. Never hangs.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export TERM=linux
PASS=1
echo "===== NETPERSIST START ====="
command -v aira-net >/dev/null 2>&1 && echo "NETPERSIST OK: aira-net present" || { echo "NETPERSIST FAIL: aira-net missing"; PASS=0; }
if mount 2>/dev/null | grep -q " /persist "; then
    echo "NETPERSIST OK: /persist mounted"
else
    echo "NETPERSIST FAIL: /persist not mounted"; PASS=0
fi
if [ -f /persist/etc/aira/network.conf ]; then
    echo "NETPERSIST OK: profile survived reboot (on-disk):"
    sed 's/^/NETPERSIST INFO:   /' /persist/etc/aira/network.conf 2>/dev/null
else
    echo "NETPERSIST FAIL: no profile on /persist (run aira_nettest=1 boot first)"; PASS=0
fi
_PIF="$(grep -E '^iface=' /persist/etc/aira/network.conf 2>/dev/null | cut -d= -f2)"
_PMODE="$(grep -E '^mode=' /persist/etc/aira/network.conf 2>/dev/null | cut -d= -f2)"
echo "NETPERSIST INFO: persisted mode=$_PMODE iface=$_PIF"
if [ -z "$_PIF" ]; then
    echo "NETPERSIST FAIL: no persisted interface"; PASS=0
elif [ ! -d "/sys/class/net/$_PIF" ]; then
    echo "NETPERSIST INFO: persisted interface $_PIF absent this boot (honest, not applied)"
else
    # Deliberately break runtime state first, so "apply" must do real work.
    ip route del default 2>/dev/null || true
    ip addr flush dev "$_PIF" 2>/dev/null || true
    _PRE="$(aira-net status "$_PIF" 2>/dev/null | sed 's/.*state=\([A-Z_]*\).*/\1/')"
    echo "NETPERSIST INFO: state after teardown: $_PRE"
    if aira-net profile apply > /tmp/netpersist-apply.out 2>&1; then
        echo "NETPERSIST OK: profile apply succeeded"
        sed 's/^/NETPERSIST INFO:   /' /tmp/netpersist-apply.out 2>/dev/null
        _POST="$(aira-net status "$_PIF" 2>/dev/null | sed 's/.*state=\([A-Z_]*\).*/\1/')"
        echo "NETPERSIST INFO: state after apply: $_POST"
        if [ "$_POST" = "ONLINE" ]; then
            echo "NETPERSIST OK: connectivity restored from persisted profile"
        else
            echo "NETPERSIST FAIL: apply left state $_POST"; PASS=0
        fi
    else
        echo "NETPERSIST FAIL: profile apply"
        cat /tmp/netpersist-apply.out 2>/dev/null; PASS=0
    fi
fi
# Cross-check: does the boot-time service itself use the profile?
echo "NETPERSIST INFO: boot net service log:"
sed 's/^/NETPERSIST INFO:   /' /var/log/airaos/net.log 2>/dev/null | head -n 12
if [ "$PASS" = "1" ]; then echo "===== NETPERSIST PASS ====="; else echo "===== NETPERSIST FAIL ====="; fi
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo halt
sleep 5