#!/usr/bin/env bash
# test-input.sh — verify Xorg input devices and basic event delivery.
# Runs in guest via aira_inputtest=1 cmdline. Exits 0 on PASS, non-zero on FAIL.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

PASS=1
echo "===== INPUT REGRESSION TEST ====="
echo "--- Xorg status ---"
if pgrep -x Xorg >/dev/null; then
  echo "INPUT OK: Xorg running"
else
  echo "INPUT FAIL: Xorg not running"
  PASS=0
fi

echo "--- JWM status ---"
if pgrep -x jwm >/dev/null; then
  echo "INPUT OK: JWM running"
else
  echo "INPUT FAIL: JWM not running"
  PASS=0
fi

echo "--- DISPLAY env ---"
if [ -n "${DISPLAY:-}" ]; then
  echo "INPUT OK: DISPLAY=$DISPLAY"
else
  echo "INPUT FAIL: DISPLAY not set"
  PASS=0
fi

echo "--- X socket ---"
if [ -S "/tmp/.X11-unix/X0" ]; then
  echo "INPUT OK: X socket present"
else
  echo "INPUT FAIL: X socket missing"
  PASS=0
fi

echo "--- Kernel input devices ---"
N_EV=$(ls /dev/input/event* 2>/dev/null | wc -l)
echo "event nodes: $N_EV"
if [ "$N_EV" -ge 2 ]; then
  echo "INPUT OK: sufficient event nodes"
else
  echo "INPUT FAIL: too few event nodes"
  PASS=0
fi

echo "--- X input devices (xinput) ---"
if command -v xinput >/dev/null 2>&1; then
  xinput list 2>/dev/null | head -n 20
  # Check for physical (non-XTEST) keyboard and pointer
  KBD=0
  PTR=0
  xinput list 2>/dev/null > /tmp/test-input-xinput.log
  if grep -i "keyboard" /tmp/test-input-xinput.log 2>/dev/null | grep -vi "xtest\|virtual core" | grep -q .; then
    KBD=1
  fi
  if grep -iE "pointer|mouse" /tmp/test-input-xinput.log 2>/dev/null | grep -vi "xtest\|virtual core" | grep -q .; then
    PTR=1
  fi
  [ "$KBD" = "1" ] && echo "INPUT OK: X keyboard device present" || { echo "INPUT FAIL: no X keyboard"; PASS=0; }
  [ "$PTR" = "1" ] && echo "INPUT OK: X pointer device present" || { echo "INPUT FAIL: no X pointer"; PASS=0; }
else
  echo "INPUT FAIL: xinput not available"
  PASS=0
fi

echo "--- Xorg log input section ---"
if [ -f /var/log/Xorg.0.log ]; then
  grep -iE "evdev|input device|keyboard|pointer|mouse" /var/log/Xorg.0.log 2>/dev/null | head -n 15
  if grep -q "evdev" /var/log/Xorg.0.log 2>/dev/null; then
    echo "INPUT OK: evdev driver loaded in Xorg"
  else
    echo "INPUT FAIL: evdev driver not found in Xorg log"
    PASS=0
  fi
else
  echo "INPUT FAIL: Xorg log missing"
  PASS=0
fi

echo "--- Application connectivity ---"
# Verify a graphical app can connect to the display
if timeout 5 xterm -T "InputTest-Term" -e true 2>/dev/null; then
  echo "INPUT OK: xterm can connect to display"
else
  echo "INPUT FAIL: xterm cannot connect to display"
  PASS=0
fi

echo "===== INPUT REGRESSION RESULT ====="
if [ "$PASS" = "1" ]; then
  echo "INPUT REGRESSION PASS"
  exit 0
else
  echo "INPUT REGRESSION FAIL"
  exit 1
fi