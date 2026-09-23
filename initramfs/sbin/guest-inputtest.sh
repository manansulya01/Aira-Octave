#!/bin/sh
# In-guest input verification (runs as init when aira_inputtest=1 is on the
# kernel cmdline). Starts the AUTOMATIC desktop path, reports input hardware
# + X input devices, then listens for REAL host-injected events (QEMU monitor
# sendkey/mouse_move/mouse_button) via xinput test + xev, reports counts to
# serial, then poweroff. Never hangs.
export PATH=/persist/usr/bin:/persist/bin:/persist/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/persist/usr/lib/x86_64-linux-gnu:/persist/lib/x86_64-linux-gnu:/persist/usr/lib:/persist/lib:$LD_LIBRARY_PATH
export DISPLAY=":0"
PASS=1
echo "===== INPUTTEST START ====="
echo "--- kernel input hardware ---"
cat /proc/bus/input/devices 2>/dev/null | head -n 60
echo "--- /dev/input ---"
ls -l /dev/input/ 2>/dev/null || { echo "INPUTTEST FAIL: no /dev/input"; PASS=0; }
N_EV=$(ls /dev/input/event* 2>/dev/null | wc -l)
echo "event nodes: $N_EV"
[ "$N_EV" -ge 1 ] || { echo "INPUTTEST FAIL: no event nodes"; PASS=0; }
echo "--- starting automatic desktop ---"
if [ -x /persist/usr/bin/aira-session ]; then SES=/persist/usr/bin/aira-session;
elif [ -x /usr/bin/aira-session ]; then SES=/usr/bin/aira-session;
else echo "INPUTTEST FAIL: aira-session missing"; PASS=0; SES=""; fi
if [ -n "$SES" ]; then
  sh "$SES" --display :0 >/tmp/inputtest-session.log 2>&1 &
  SESPID=$!
fi
i=0
while [ "$i" -lt 90 ]; do
  [ -S /tmp/.X11-unix/X0 ] && break
  sleep 2
  i=$((i+1))
done
[ -S /tmp/.X11-unix/X0 ] || { echo "INPUTTEST FAIL: no X socket"; PASS=0; }
sleep 5
echo "--- Xorg input section ---"
grep -iE "input|keyboard|pointer|mouse|libinput|evdev|xtest" /var/log/Xorg.0.log 2>/dev/null | head -n 30
grep -iE "\(EE\)" /var/log/Xorg.0.log 2>/dev/null | grep -vi "dbus\|aiglx\|glx\|software renderer" | head -n 10
echo "--- xinput list ---"
if command -v xinput >/dev/null 2>&1; then
  xinput list 2>&1 | head -n 25
  xinput list 2>/dev/null > /tmp/inputtest-xinput.log
else
  echo "INPUTTEST INFO: xinput missing"
fi
echo "--- session env ---"
echo "DISPLAY=$DISPLAY"
ps 2>/dev/null | grep -E "[X]org|[j]wm" | head -n 4
if ps 2>/dev/null | grep -q "[X]org" && ps 2>/dev/null | grep -q "[j]wm"; then
  echo "INPUTTEST OK: Xorg + JWM running"
else
  echo "INPUTTEST FAIL: Xorg/JWM missing"; PASS=0
fi
# Physical (non-XTEST) keyboard + pointer in X. Virtual-core masters always
# exist, so require slave/client lines that are not XTEST.
KBD=0; PTR=0
if [ -f /tmp/inputtest-xinput.log ]; then
  grep -i "keyboard" /tmp/inputtest-xinput.log 2>/dev/null | grep -vi "xtest\|virtual core" | grep -q . && KBD=1
  grep -iE "pointer|mouse" /tmp/inputtest-xinput.log 2>/dev/null | grep -vi "xtest\|virtual core" | grep -q . && PTR=1
  echo "physical X input lines:"
  grep -vi "xtest\|virtual core" /tmp/inputtest-xinput.log 2>/dev/null | head -n 10
fi
[ "$KBD" = "1" ] && echo "INPUTTEST OK: X keyboard device present" || { echo "INPUTTEST FAIL: no X keyboard"; PASS=0; }
[ "$PTR" = "1" ] && echo "INPUTTEST OK: X pointer device present" || { echo "INPUTTEST FAIL: no X pointer"; PASS=0; }
echo "--- opening a terminal for focused input ---"
timeout 120 aira-terminal &
sleep 4
echo "--- arming event listeners (xinput test on every device + xev) ---"
rm -f /tmp/inputtest-events.log
if command -v xinput >/dev/null 2>&1; then
  for id in $(xinput list --id-only 2>/dev/null); do
    ( timeout 60 xinput test "$id" >>/tmp/inputtest-events.log 2>&1 & ) 2>/dev/null
  done
fi
( timeout 60 xev -event keyboard -event mouse > /tmp/inputtest-xev.log 2>&1 & ) 2>/dev/null
sleep 2
echo "INPUTTEST LISTENING (host: send keys + mouse now)"
# Interrupt baselines: prove whether emulated hardware events reach the kernel.
grep -E "i8042|virtio" /proc/interrupts 2>/dev/null | head -n 8 > /tmp/inputtest-irq-before.log
cat /tmp/inputtest-irq-before.log
# Listening window for host-injected QEMU monitor events.
sleep 45
echo "--- interrupt deltas (hardware delivery proof) ---"
grep -E "i8042|virtio" /proc/interrupts 2>/dev/null | head -n 8 > /tmp/inputtest-irq-after.log
cat /tmp/inputtest-irq-after.log
dmesg 2>/dev/null | grep -iE "8042|serio|input.*(error|fail)" | tail -n 5
echo "--- event capture results ---"
wc -l /tmp/inputtest-events.log /tmp/inputtest-xev.log 2>/dev/null
grep -c "key press" /tmp/inputtest-events.log 2>/dev/null | xargs echo "xinput key-press lines:"
grep -c "button press" /tmp/inputtest-events.log 2>/dev/null | xargs echo "xinput button-press lines:"
grep -c "motion" /tmp/inputtest-events.log 2>/dev/null | xargs echo "xinput motion lines:"
grep -c "KeyPress" /tmp/inputtest-xev.log 2>/dev/null | xargs echo "xev KeyPress lines:"
grep -c "ButtonPress" /tmp/inputtest-xev.log 2>/dev/null | xargs echo "xev ButtonPress lines:"
grep -c "MotionNotify" /tmp/inputtest-xev.log 2>/dev/null | xargs echo "xev MotionNotify lines:"
cnt() { # $1=file $2=pattern -> prints number (0 if none)
  c=$(grep -c "$2" "$1" 2>/dev/null || true)
  [ -n "$c" ] || c=0
  # grep -c prints exactly one number; take first line for safety
  echo "$c" | head -n1
}
KP=$(cnt /tmp/inputtest-events.log "key press")
MP=$(cnt /tmp/inputtest-events.log "motion")
BP=$(cnt /tmp/inputtest-events.log "button press")
XK=$(cnt /tmp/inputtest-xev.log "KeyPress")
echo "INPUTTEST counts: xinput_keys=$KP xinput_motion=$MP xinput_buttons=$BP xev_keys=$XK"
if [ "${KP:-0}" -ge 1 ] 2>/dev/null; then echo "INPUTTEST OK: real key event reached X";
else echo "INPUTTEST FAIL: no key events captured"; PASS=0; fi
if [ "${MP:-0}" -ge 1 ] 2>/dev/null; then echo "INPUTTEST OK: real pointer motion reached X";
else echo "INPUTTEST FAIL: no pointer motion captured"; PASS=0; fi
if [ "${BP:-0}" -ge 1 ] 2>/dev/null; then echo "INPUTTEST OK: real button event reached X";
else echo "INPUTTEST INFO: no button events (non-fatal if motion+keys work)"; fi
echo "--- doctor ---"
/usr/bin/aira doctor >/tmp/inputtest-doctor.log 2>&1 && echo "INPUTTEST OK: doctor PASS" || { echo "INPUTTEST FAIL: doctor"; PASS=0; }
mkdir -p /persist/screenshots 2>/dev/null || true
cp -f /var/log/Xorg.0.log /persist/screenshots/Xorg-input.log 2>/dev/null || true
cp -f /tmp/xorg-visible.conf /persist/screenshots/xorg-visible.conf 2>/dev/null || true
kill $SESPID 2>/dev/null
if [ "$PASS" = "1" ]; then echo "===== INPUTTEST PASS ====="; else echo "===== INPUTTEST FAIL ====="; fi
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo halt
sleep 5
