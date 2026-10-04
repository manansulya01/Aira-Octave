#!/bin/sh
# In-guest settings verification (runs as init when aira_settingstest=1).
# Exercises the C2 central store: get/set/reset/list/validate/caps over the
# bus path when reachable, corruption + concurrency + privilege denial.
# Prints SETTINGS markers to serial, then poweroff. Never hangs.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export TERM=linux
PASS=1
echo "===== SETTINGS TEST START ====="
if command -v aira-cfg >/dev/null 2>&1; then
    echo "SETTINGS OK: aira-cfg present"
else
    echo "SETTINGS FAIL: aira-cfg missing"; PASS=0
fi
if [ -x /etc/aira/ipc/handlers/settings ]; then
    echo "SETTINGS OK: settings handler present"
else
    echo "SETTINGS FAIL: settings handler missing"; PASS=0
fi
if command -v aira-ipc >/dev/null 2>&1 && aira-ipc ping >/dev/null 2>&1; then
    echo "SETTINGS INFO: bus reachable (bus path exercised)"; _BUS=1
else
    echo "SETTINGS INFO: bus unreachable (local path exercised)"; _BUS=0
fi
# store location must prefer /persist when mounted
if mount 2>/dev/null | grep -q " /persist "; then
    _WANT_PERSIST=1
else
    _WANT_PERSIST=0
fi
aira-cfg set security.lock_timeout 600 >/dev/null 2>&1 || { echo "SETTINGS FAIL: set lock_timeout"; PASS=0; }
if [ "$(aira-cfg get security.lock_timeout 2>/dev/null)" = "security.lock_timeout=600" ]; then
    echo "SETTINGS OK: set+get roundtrip"
else
    echo "SETTINGS FAIL: set+get roundtrip"; PASS=0
fi
if [ "$_WANT_PERSIST" = "1" ]; then
    if grep -q "^security.lock_timeout=600" /persist/etc/aira/settings.conf 2>/dev/null; then
        echo "SETTINGS OK: persisted under /persist"
    else
        echo "SETTINGS FAIL: not under /persist"; PASS=0
    fi
else
    echo "SETTINGS INFO: no /persist (durable path unchecked)"
fi
aira-cfg set system.hostname "cfgtest-1" >/dev/null 2>&1
if [ "$(cat /etc/hostname 2>/dev/null)" = "cfgtest-1" ]; then
    echo "SETTINGS OK: hostname applied live"
else
    echo "SETTINGS FAIL: hostname not applied"; PASS=0
fi
if aira-cfg set system.hostname "bad_host!!" >/dev/null 2>&1; then
    echo "SETTINGS FAIL: invalid hostname accepted"; PASS=0
else
    echo "SETTINGS OK: invalid hostname rejected"
fi
if [ "$(aira-cfg get system.hostname 2>/dev/null)" = "system.hostname=cfgtest-1" ]; then
    echo "SETTINGS OK: invalid hostname rejected, old value kept"
else
    echo "SETTINGS FAIL: invalid hostname handling"; PASS=0
fi
if aira-cfg set display.opacity 999 >/dev/null 2>&1; then echo "SETTINGS FAIL: range accepted"; PASS=0;
else echo "SETTINGS OK: range rejected"; fi
if aira-cfg set nosuch.key x >/dev/null 2>&1; then echo "SETTINGS FAIL: unknown key accepted"; PASS=0;
else echo "SETTINGS OK: unknown key rejected"; fi
if aira-cfg set audio.volume 80 >/dev/null 2>&1; then echo "SETTINGS FAIL: mixer set accepted without hw"; PASS=0;
else echo "SETTINGS OK: mixer UNAVAILABLE honestly"; fi
if aira-cfg set network.wifi on >/dev/null 2>&1; then echo "SETTINGS FAIL: wifi accepted without hw"; PASS=0;
else echo "SETTINGS OK: wifi UNAVAILABLE honestly"; fi
if aira-cfg set power.brightness 50 >/dev/null 2>&1; then echo "SETTINGS FAIL: brightness accepted without hw"; PASS=0;
else echo "SETTINGS OK: brightness UNAVAILABLE honestly"; fi
aira-cfg caps 2>/dev/null | grep -q "UNAVAILABLE" && echo "SETTINGS OK: caps reports UNAVAILABLE" || { echo "SETTINGS FAIL: caps honesty"; PASS=0; }
aira-cfg list system 2>/dev/null | grep -q "system.hostname" && echo "SETTINGS OK: list namespace" || { echo "SETTINGS FAIL: list namespace"; PASS=0; }
aira-cfg reset security.lock_timeout >/dev/null 2>&1
if [ "$(aira-cfg get security.lock_timeout 2>/dev/null)" = "security.lock_timeout=300" ]; then
    echo "SETTINGS OK: reset to default"
else
    echo "SETTINGS FAIL: reset"; PASS=0
fi
echo "--- corruption handling ---"
_CONF=""
if [ "$_WANT_PERSIST" = "1" ]; then _CONF=/persist/etc/aira/settings.conf; else _CONF=/etc/aira/settings.conf; fi
printf "GARBAGE-NO-EQUALS\nbogus.key=x\nsystem.hostname=way-too-long-!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n" >> "$_CONF" 2>/dev/null
_VOUT="$(aira-cfg validate 2>/dev/null || true)"
case "$_VOUT" in *issues=*) echo "SETTINGS OK: corruption reported ($_VOUT)" ;; *) echo "SETTINGS FAIL: corruption missed"; PASS=0 ;; esac
if aira-cfg get security.lock_timeout >/dev/null 2>&1; then
    echo "SETTINGS OK: valid keys still readable when corrupt"
else
    echo "SETTINGS FAIL: corruption broke reads"; PASS=0
fi
aira-cfg reset all >/dev/null 2>&1 || true
if [ "$(aira-cfg validate 2>/dev/null)" = "clean" ]; then
    echo "SETTINGS OK: reset all cleans store"
else
    echo "SETTINGS FAIL: reset all did not clean"; PASS=0
fi
echo "--- concurrency (atomicity, not serialization) ---"
i=0; while [ "$i" -lt 8 ]; do ( aira-cfg set security.lock_timeout $((100+i)) >/dev/null 2>&1 ) & i=$((i+1)); done
_CBAD=0; j=0
while [ "$j" -lt 20 ]; do
    aira-cfg validate >/dev/null 2>&1 || _CBAD=1
    j=$((j+1))
done
wait
if [ "$_CBAD" = "0" ]; then echo "SETTINGS OK: store always parses under concurrency";
else echo "SETTINGS FAIL: torn store observed"; PASS=0; fi
_FIN="$(aira-cfg get security.lock_timeout 2>/dev/null | cut -d= -f2)"
case "$_FIN" in 100|101|102|103|104|105|106|107) echo "SETTINGS OK: last-writer-wins ($_FIN)" ;;
*) echo "SETTINGS FAIL: unexpected final value $_FIN"; PASS=0 ;; esac
aira-cfg reset security.lock_timeout >/dev/null 2>&1 || true
echo "--- privilege denial ---"
if su aira -c 'aira-cfg set security.lock_timeout 111' >/dev/null 2>&1; then
    echo "SETTINGS FAIL: unprivileged set allowed"; PASS=0
else
    echo "SETTINGS OK: unprivileged set denied"
fi
if [ "$PASS" = "1" ]; then echo "===== SETTINGS TEST PASS ====="; else echo "===== SETTINGS TEST FAIL ====="; fi
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo halt
sleep 5
