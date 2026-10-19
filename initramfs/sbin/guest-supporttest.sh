#!/bin/sh
# Guest integration test for the aira-support-bundle command.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export TERM=linux
PASS=1
OUT="/tmp/aira-supporttest.tar.gz"
LIST="/tmp/aira-supporttest.list"
LOG="/tmp/aira-supporttest-create.log"
t() {
  desc="$1"; shift
  if "$@" >/tmp/aira-supporttest-command.out 2>&1; then
    echo "GUEST-SUPPORT-TEST OK: $desc"
  else
    echo "GUEST-SUPPORT-TEST FAIL: $desc"
    cat /tmp/aira-supporttest-command.out
    PASS=0
  fi
}
contains() {
  desc="$1"; file="$2"; pattern="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    echo "GUEST-SUPPORT-TEST OK: $desc"
  else
    echo "GUEST-SUPPORT-TEST FAIL: $desc"
    PASS=0
  fi
}
echo "===== GUEST SUPPORT BUNDLE TEST START ====="
rm -f "$OUT" "$LIST" "$LOG"
t "CLI creates archive" sh -c "/usr/bin/aira support-bundle '$OUT' > '$LOG' 2>&1"
contains "success marker" "$LOG" "SUPPORT BUNDLE CREATED"
t "archive readable" tar -tzf "$OUT"
tar -tzf "$OUT" > "$LIST" 2>/dev/null
contains "system report included" "$LIST" "system.txt"
contains "resource report included" "$LIST" "resources.txt"
contains "network report included" "$LIST" "network.txt"
contains "doctor report included" "$LIST" "doctor.txt"
if grep -Eq '(^|/)(passwd|shadow|gshadow|root[.]token)$' "$LIST"; then
  echo "GUEST-SUPPORT-TEST FAIL: credential file path included"
  PASS=0
else
  echo "GUEST-SUPPORT-TEST OK: credential file paths excluded"
fi
if [ -s "$OUT" ]; then
  echo "GUEST-SUPPORT-TEST OK: archive non-empty"
else
  echo "GUEST-SUPPORT-TEST FAIL: archive empty"
  PASS=0
fi
rm -f "$OUT" "$LIST" "$LOG" /tmp/aira-supporttest-command.out
if [ "$PASS" -eq 1 ]; then
  echo "===== GUEST SUPPORT BUNDLE TEST PASS ====="
else
  echo "===== GUEST SUPPORT BUNDLE TEST FAIL ====="
fi
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo "halt"
sleep 5
