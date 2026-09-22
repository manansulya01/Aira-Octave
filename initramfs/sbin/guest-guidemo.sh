#!/bin/sh
# AiraOS graphical demo: opens a tiled showroom of REAL apps (runs in
# background when aira_guidemo=1 is on the kernel cmdline). 2x2 grid plus an
# About dialog. Never blocks, never powers off.
export PATH=/persist/usr/bin:/persist/bin:/persist/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/persist/usr/lib/x86_64-linux-gnu:/persist/lib/x86_64-linux-gnu:/persist/usr/lib:/persist/lib:$LD_LIBRARY_PATH
export DISPLAY=":0"
XT="xterm -fa Monospace -fs 10 -bg #0b1026 -fg #e8ecff -sb"
echo "===== GUIDEMO START (desktop showroom) ====="
i=0
while [ "$i" -lt 60 ]; do
  [ -S /tmp/.X11-unix/X0 ] && break
  sleep 2
  i=$((i+1))
done
[ -S /tmp/.X11-unix/X0 ] || { echo "GUIDEMO FAIL: no X display"; exit 1; }
sleep 4
# Tiled 2x2 grid (top tray 26px, bottom taskbar 28px on 1024x768).
$XT -T "AiraOS Terminal" -geometry 36x14+8+34 -e "${SHELL:-/bin/sh}" >/dev/null 2>&1 &
sleep 1
$XT -T "AiraOS File Manager" -geometry 36x14+516+34 -e mc ~ >/dev/null 2>&1 &
sleep 1
$XT -T "AiraOS System Monitor" -geometry 36x14+8+400 -e sh -c 'while true; do clear; aira-sysmon --once; sleep 2; done' >/dev/null 2>&1 &
sleep 1
$XT -T "AiraOS Settings" -geometry 36x14+516+400 -e sh /persist/usr/bin/aira-settings --noterm >/dev/null 2>&1 &
sleep 2
aira-about >/dev/null 2>&1 &
echo "GUIDEMO OK: showroom open (terminal, files, monitor, settings, about)"
# Long settle: tray swallowing + window resize under emulation is slow.
sleep 30
xwininfo -root -children 2>/dev/null | head -n 30
echo "===== GUIDEMO READY ====="
