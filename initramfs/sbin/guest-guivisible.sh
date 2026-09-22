#!/bin/sh
# In-guest visible-desktop verification (runs as init when aira_guivisible=1
# is on the kernel cmdline). Boots the AUTOMATIC desktop path (same as
# aira_gui=1), then proves the VISIBLE Xorg backend came up: DRM device,
# Xorg modesetting log, root window, real JWM children, a real xterm window
# and a real Aira app window, plus an xwd screenshot. Prints GUIVIS markers
# to serial, then poweroff. Never hangs.
export PATH=/persist/usr/bin:/persist/bin:/persist/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/persist/usr/lib/x86_64-linux-gnu:/persist/lib/x86_64-linux-gnu:/persist/usr/lib:/persist/lib:$LD_LIBRARY_PATH
PASS=1
export DISPLAY=":0"
echo "===== GUIVIS START ====="
echo "--- graphics hardware ---"
ls -l /dev/dri/ 2>&1
lspci 2>/dev/null | head -n 10 || ls /sys/bus/pci/devices/ 2>/dev/null | head -n 10
if ls /dev/dri/card* >/dev/null 2>&1; then
  echo "GUIVIS OK: DRM card present (visible GPU)"
else
  echo "GUIVIS FAIL: no /dev/dri/card* (need virtio GPU on QEMU cmdline)"; PASS=0
fi
echo "--- starting automatic desktop (same path as aira_gui=1) ---"
if [ -x /persist/usr/bin/aira-session ]; then SES=/persist/usr/bin/aira-session;
elif [ -x /usr/bin/aira-session ]; then SES=/usr/bin/aira-session;
else echo "GUIVIS FAIL: aira-session missing"; PASS=0; SES=""; fi
if [ -n "$SES" ]; then
  sh "$SES" --display :0 >/tmp/guivisible-session.log 2>&1 &
  SESPID=$!
  echo "session pid $SESPID"
fi
# Wait for the X socket (generous: TCG is slow, Xorg+JWM take a while)
i=0
while [ "$i" -lt 90 ]; do
  [ -S /tmp/.X11-unix/X0 ] && break
  sleep 2
  i=$((i+1))
done
if [ -S /tmp/.X11-unix/X0 ]; then
  echo "GUIVIS OK: X socket :0 ready after ~$((i*2))s"
else
  echo "GUIVIS FAIL: X socket :0 never appeared"; PASS=0
fi
cat /tmp/guivisible-session.log 2>/dev/null | head -n 20
echo "--- X server identity (must be VISIBLE Xorg, not Xvfb) ---"
ps 2>/dev/null | grep -E "Xorg|Xvfb" | grep -v grep 2>/dev/null | head -n 5
if ps 2>/dev/null | grep -q "[X]org"; then
  echo "GUIVIS OK: Xorg process running (visible backend)"
else
  echo "GUIVIS FAIL: Xorg not running"; PASS=0
fi
if ps 2>/dev/null | grep -q "[X]vfb"; then
  echo "GUIVIS FAIL: Xvfb running (invisible fallback took over)"; PASS=0
else
  echo "GUIVIS OK: Xvfb not running"
fi
if grep -qi "modesetting" /var/log/Xorg.0.log /tmp/Xorg.log 2>/dev/null; then
  echo "GUIVIS OK: Xorg modesetting driver active"
  grep -ih "modesetting" /var/log/Xorg.0.log /tmp/Xorg.log 2>/dev/null | head -n 3
else
  echo "GUIVIS INFO: modesetting not in Xorg log (trying vesa/fbdev fallback?)"
  head -n 30 /var/log/Xorg.0.log /tmp/Xorg.log 2>/dev/null
fi
echo "--- desktop + real app windows (full set) ---"
sleep 3
xwininfo -root 2>/dev/null | head -n 8 || { echo "GUIVIS FAIL: xwininfo root"; PASS=0; }
xterm -T "AiraVisible-Term" -e sh -c 'sleep 120' &
TPID=$!
timeout 120 aira-terminal &
TTPID=$!
timeout 120 aira-file-manager &
FMPID=$!
timeout 120 aira-sysmon &
SMPID=$!
timeout 120 aira-settings &
STPID=$!
timeout 120 aira-textedit &
TEPID=$!
timeout 120 aira-pkgcenter &
PCPID=$!
timeout 120 aira-netman &
NMPID=$!
sh "$(command -v aira-sysinfo)" >/dev/null 2>&1 &
SYSMSG_PID=$!
sh "$(command -v aira-about)" >/dev/null 2>&1 &
APID=$!
# Poll until the named windows are mapped (up to ~120s).
# Transient counts are ignored; named windows are the real proof.
found_term=0
found_apps=0
i=0
while [ "$i" -lt 60 ]; do
  xwininfo -root -children 2>/dev/null > /tmp/guivisible-windows.log
  n=$(grep -c "0x[0-9a-f]* (" /tmp/guivisible-windows.log 2>/dev/null || true)
  [ -n "$n" ] || n=0
  grep -q "AiraVisible-Term" /tmp/guivisible-windows.log 2>/dev/null && found_term=1
  if grep -q "AiraOS Terminal" /tmp/guivisible-windows.log 2>/dev/null \
    && grep -q "AiraOS File Manager" /tmp/guivisible-windows.log 2>/dev/null \
    && grep -q "AiraOS System Monitor" /tmp/guivisible-windows.log 2>/dev/null; then
    found_apps=1
  fi
  if [ "$found_term" = "1" ] && [ "$found_apps" = "1" ] && [ "$n" -ge 6 ]; then
    echo "GUIVIS OK: app windows mapped after ~$((i*2))s ($n children)"
    break
  fi
  sleep 2
  i=$((i+1))
done
# Let windows finish mapping/resizing into their staggered geometries
# before the screenshot + final listing (JWM under emulation is slow).
sleep 8
xwininfo -root -children 2>/dev/null > /tmp/guivisible-windows.log
cat /tmp/guivisible-windows.log 2>/dev/null | head -n 40
n=$(grep -c "0x[0-9a-f]* (" /tmp/guivisible-windows.log 2>/dev/null || true)
[ -n "$n" ] || n=0
if [ "$found_term" = "1" ] && [ "$found_apps" = "1" ] && [ "$n" -ge 6 ]; then echo "GUIVIS OK: JWM desktop + app windows visible ($n)";
else echo "GUIVIS FAIL: only $n windows (need >=6 incl. named apps)"; PASS=0; fi
if [ "$found_term" = "1" ] && [ "$found_apps" = "1" ]; then
  echo "GUIVIS OK: real app windows present (terminal, files, monitor)"
else
  echo "GUIVIS FAIL: named app windows missing"; PASS=0
fi
xlsclients 2>/dev/null | tee /tmp/guivisible-clients.log | head -n 10
if grep -qi "xterm" /tmp/guivisible-clients.log 2>/dev/null; then
  echo "GUIVIS OK: xterm client registered"
else
  echo "GUIVIS INFO: xlsclients empty/slow (non-fatal)"
fi
xwd -root -out /tmp/guivisible-shot.xwd 2>/dev/null && echo "GUIVIS OK: xwd screenshot $(wc -c < /tmp/guivisible-shot.xwd) bytes" || echo "GUIVIS INFO: xwd failed (non-fatal)"
mkdir -p /persist/screenshots 2>/dev/null || true
cp -f /tmp/guivisible-shot.xwd /persist/screenshots/guivisible.xwd 2>/dev/null || true
cp -f /var/log/Xorg.0.log /persist/screenshots/Xorg-visible.log 2>/dev/null || cp -f /tmp/Xorg.log /persist/screenshots/Xorg-visible.log 2>/dev/null || true
if pidof jwm >/dev/null 2>&1 || ps 2>/dev/null | grep -q "[j]wm"; then
  echo "GUIVIS OK: jwm desktop running"
else
  echo "GUIVIS FAIL: jwm not running"; PASS=0
fi
echo "--- doctor (must still pass with visible desktop) ---"
/usr/bin/aira doctor > /tmp/guivisible-doctor.log 2>&1 && echo "GUIVIS OK: aira doctor PASS" || { echo "GUIVIS FAIL: aira doctor"; cat /tmp/guivisible-doctor.log 2>&1; PASS=0; }
grep -E "DOCTOR" /tmp/guivisible-doctor.log 2>/dev/null | head -n 2
kill $TPID $TTPID $FMPID $SMPID $STPID $TEPID $PCPID $NMPID $APID ${SYSMSG_PID:-} $SESPID 2>/dev/null
# desktop must survive app exit
sleep 1
if pidof jwm >/dev/null 2>&1 || ps 2>/dev/null | grep -q "[j]wm"; then
  echo "GUIVIS OK: desktop survives apps"
else
  echo "GUIVIS FAIL: jwm died after app close"; PASS=0
fi
if [ "$PASS" = "1" ]; then echo "===== GUIVISIBLE PASS =====";
else echo "===== GUIVISIBLE FAIL ====="; fi
echo "powering off"
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo "halt"
sleep 5
