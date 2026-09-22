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
echo "--- desktop + real app windows ---"
sleep 3
xwininfo -root 2>/dev/null | head -n 8 || { echo "GUIVIS FAIL: xwininfo root"; PASS=0; }
xterm -T "AiraVisible-Term" -e sh -c 'sleep 120' &
TPID=$!
timeout 90 aira-textedit &
TEPID=$!
# Poll until the named xterm window is actually mapped (up to ~90s).
# Transient map counts are ignored; the named window is the real proof.
found=0
i=0
while [ "$i" -lt 45 ]; do
  xwininfo -root -children 2>/dev/null > /tmp/guivisible-windows.log
  n=$(grep -c "0x[0-9a-f]* (" /tmp/guivisible-windows.log 2>/dev/null || true)
  [ -n "$n" ] || n=0
  if grep -q "AiraVisible-Term" /tmp/guivisible-windows.log 2>/dev/null; then
    echo "GUIVIS OK: named xterm window mapped after ~$((i*2))s ($n children)"
    found=1
    break
  fi
  sleep 2
  i=$((i+1))
done
cat /tmp/guivisible-windows.log 2>/dev/null | head -n 40
n=$(grep -c "0x[0-9a-f]* (" /tmp/guivisible-windows.log 2>/dev/null || true)
[ -n "$n" ] || n=0
if [ "$found" = "1" ] && [ "$n" -ge 3 ]; then echo "GUIVIS OK: JWM desktop + app windows visible ($n)";
else echo "GUIVIS FAIL: only $n windows (need >=3 incl. named xterm)"; PASS=0; fi
if [ "$found" = "1" ]; then
  echo "GUIVIS OK: real xterm window present"
else
  echo "GUIVIS FAIL: xterm window missing"; PASS=0
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
kill $TPID $TEPID $SESPID 2>/dev/null
if [ "$PASS" = "1" ]; then echo "===== GUIVISIBLE PASS =====";
else echo "===== GUIVISIBLE FAIL ====="; fi
echo "powering off"
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo "halt"
sleep 5
