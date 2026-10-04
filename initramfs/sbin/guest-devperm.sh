#!/bin/sh
# In-guest device-permission verification (runs when aira_devperm=1).
# Proves the C5 prerequisite fix: standard /dev nodes are usable by an
# unprivileged user, privileged nodes are NOT, and the IPC bus works as uid
# 1000. Prints DEVPERM markers to serial, then poweroff. Never hangs.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export TERM=linux
PASS=1
echo "===== DEVPERM START ====="
for n in null zero full random urandom; do
  if [ -c "/dev/$n" ]; then
    printf "DEVPERM INFO: /dev/%s %s\n" "$n" "$(ls -l "/dev/$n" 2>/dev/null | awk '{print $1, $3, $4}')"
  else
    echo "DEVPERM INFO: /dev/$n absent (devtmpfs may omit it)"
  fi
done
echo "--- root can use /dev/null ---"
if echo probe > /dev/null 2>&1; then echo "DEVPERM OK: root write /dev/null"; else echo "DEVPERM FAIL: root /dev/null"; PASS=0; fi
echo "--- unprivileged can use /dev/null (the C5 prerequisite) ---"
if su -s /bin/sh aira -c 'echo probe > /dev/null && echo aira-null-write-ok' > /tmp/devperm-null.out 2>&1; then
  if grep -q "aira-null-write-ok" /tmp/devperm-null.out 2>/dev/null; then
    echo "DEVPERM OK: aira can write /dev/null"
  else
    echo "DEVPERM FAIL: aira /dev/null write: $(cat /tmp/devperm-null.out 2>/dev/null)"; PASS=0
  fi
else
  echo "DEVPERM FAIL: aira could not run redirect: $(cat /tmp/devperm-null.out 2>/dev/null)"; PASS=0
fi
echo "--- unprivileged can read /dev/urandom ---"
if su -s /bin/sh aira -c 'head -c 8 /dev/urandom > /dev/null' >/dev/null 2>&1; then
  echo "DEVPERM OK: aira can read /dev/urandom"
else
  echo "DEVPERM FAIL: aira cannot read /dev/urandom"; PASS=0
fi
echo "--- privileged nodes stay protected ---"
for n in /etc/shadow /run/aira-ipc/root.token; do
  if [ -e "$n" ]; then
    if su -s /bin/sh aira -c "cat $n" >/dev/null 2>&1; then
      echo "DEVPERM FAIL: aira can read $n"; PASS=0
    else
      echo "DEVPERM OK: $n denied to aira"
    fi
  fi
done
echo "--- IPC bus usable as unprivileged (positive control) ---"
if su -s /bin/sh aira -c 'aira-ipc ping devperm-probe' > /tmp/devperm-ping.out 2>&1 \
   && grep -q pong /tmp/devperm-ping.out 2>/dev/null; then
  echo "DEVPERM OK: aira reaches the IPC bus"
else
  echo "DEVPERM FAIL: aira cannot use the IPC bus: $(cat /tmp/devperm-ping.out 2>/dev/null)"; PASS=0
fi
if su -s /bin/sh aira -c 'aira-net list' > /tmp/devperm-net.out 2>&1 && grep -q "^lo|" /tmp/devperm-net.out 2>/dev/null; then
  echo "DEVPERM OK: aira reads interface state (open method)"
else
  echo "DEVPERM FAIL: aira cannot read network state: $(cat /tmp/devperm-net.out 2>/dev/null)"; PASS=0
fi
echo "--- privileged network mutation still denied to aira ---"
IF=""
for c in /sys/class/net/*; do n=$(basename "$c" 2>/dev/null); [ "$n" = "lo" ] && continue; IF="$n"; break; done
if [ -n "$IF" ]; then
  if su -s /bin/sh aira -c "aira-net down $IF" >/dev/null 2>&1; then
    echo "DEVPERM FAIL: aira mutated a link"; PASS=0
  else
    echo "DEVPERM OK: aira link mutation denied"
  fi
else
  echo "DEVPERM INFO: no non-loopback interface (boot with --net user)"
fi
rm -f /tmp/devperm-null.out /tmp/devperm-ping.out /tmp/devperm-net.out
if [ "$PASS" = "1" ]; then echo "===== DEVPERM PASS ====="; else echo "===== DEVPERM FAIL ====="; fi
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo halt
sleep 5