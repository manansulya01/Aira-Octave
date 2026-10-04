#!/bin/sh
# In-guest monitor verification (runs as init when aira_monitest=1).
# Proves the C4 single-snapshot backend: complete sections, caps honesty
# for absent sensors, speed (well under the 10s handler timeout), and the
# watch loop's first frame. Prints MONTEST markers, then poweroff.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export TERM=linux
PASS=1
echo "===== MONTEST START ====="
command -v aira-sysstat >/dev/null 2>&1 && echo "MONTEST OK: aira-sysstat present" || { echo "MONTEST FAIL: aira-sysstat missing"; PASS=0; }
[ -x /etc/aira/ipc/handlers/sysstat ] && echo "MONTEST OK: sysstat handler present" || { echo "MONTEST FAIL: sysstat handler missing"; PASS=0; }
aira-sysstat snapshot > /tmp/montest-snap.out 2>&1 || { echo "MONTEST FAIL: snapshot rc"; PASS=0; }
ck() {
    if grep -q "$2" /tmp/montest-snap.out 2>/dev/null; then echo "MONTEST OK: $1";
    else echo "MONTEST FAIL: $1"; PASS=0; fi
}
ck "cpu model" "^cpu.model="
ck "cpu count" "^cpu.cpus="
ck "cpu busy pct" "^cpu.busy_pct="
ck "load" "^load.1="
ck "uptime" "^uptime.s="
ck "mem total" "^mem.total_kb="
ck "mem used pct" "^mem.used_pct="
ck "proc count" "^procs.count="
ck "top rows" "^top="
ck "storage root" "^storage=/|"
ck "net rows" "^net="
ck "services" "^svc.running="
_CAPS="$(aira-sysstat caps 2>/dev/null || true)"
echo "$_CAPS" | grep -q "thermal=" && echo "MONTEST OK: caps thermal field" || { echo "MONTEST FAIL: caps thermal"; PASS=0; }
case "$_CAPS" in *thermal=no*)
    grep -q "^thermal=" /tmp/montest-snap.out 2>/dev/null && { echo "MONTEST FAIL: phantom thermal"; PASS=0; } || echo "MONTEST OK: no phantom thermal"
    ;;
*) echo "MONTEST INFO: thermal present (hardware has sensors)" ;;
esac
case "$_CAPS" in *battery=no*)
    grep -q "^battery=" /tmp/montest-snap.out 2>/dev/null && { echo "MONTEST FAIL: phantom battery"; PASS=0; } || echo "MONTEST OK: no phantom battery"
    ;;
*) echo "MONTEST INFO: battery present" ;;
esac
if command -v aira-ipc >/dev/null 2>&1 && aira-ipc ping >/dev/null 2>&1; then
    if aira-ipc call sysstat bogus >/dev/null 2>&1; then echo "MONTEST FAIL: bus unknown accepted"; PASS=0;
    else echo "MONTEST OK: bus unknown rejected"; fi
    if aira-ipc call sysstat snapshot extra-arg >/dev/null 2>&1; then echo "MONTEST FAIL: bus args accepted"; PASS=0;
    else echo "MONTEST OK: bus args rejected"; fi
else
    echo "MONTEST INFO: bus down (bus-path checks skipped)"
fi
_S0="$(date +%s 2>/dev/null || echo 0)"
i=0; while [ "$i" -lt 3 ]; do aira-sysstat snapshot >/dev/null 2>&1 || { echo "MONTEST FAIL: repeat $i"; PASS=0; }; i=$((i+1)); done
_S1="$(date +%s 2>/dev/null || echo 0)"
_DT=$((_S1-_S0))
if [ "$_DT" -lt 27 ]; then echo "MONTEST OK: 3 snapshots in ${_DT}s";
else echo "MONTEST FAIL: too slow (${_DT}s)"; PASS=0; fi
timeout 8 aira-sysstat watch 1 > /tmp/montest-watch.out 2>&1 || true
grep -q "System Monitor" /tmp/montest-watch.out 2>/dev/null && grep -q "cpu.busy_pct" /tmp/montest-watch.out 2>/dev/null && echo "MONTEST OK: watch first frames" || { echo "MONTEST FAIL: watch output"; PASS=0; }
if command -v aira-sysmon >/dev/null 2>&1 || [ -x /persist/usr/bin/aira-sysmon ]; then
    _SM="aira-sysmon"; command -v aira-sysmon >/dev/null 2>&1 || _SM=/persist/usr/bin/aira-sysmon
    "$_SM" --once > /tmp/montest-mon.out 2>&1 && grep -q "cpu.busy_pct" /tmp/montest-mon.out 2>/dev/null && echo "MONTEST OK: sysmon uses snapshot backend" || { echo "MONTEST FAIL: sysmon backend"; PASS=0; }
else
    echo "MONTEST INFO: sysmon not in image (backend assumed)"
fi
if [ "$PASS" = "1" ]; then echo "===== MONTEST PASS ====="; else echo "===== MONTEST FAIL ====="; fi
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo halt
sleep 5
