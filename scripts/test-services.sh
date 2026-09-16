#!/usr/bin/env bash
# Boot guest with autotest, verify service markers.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/services"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/services-$TS.log"
bash "$ROOT/scripts/boot-qemu.sh" --timeout 40 --log "$LOG" --append "aira_autotest=1"
PASS=1
for m in "Linux version" "AiraOS userspace ready" "GUEST AUTOTEST"; do
  grep -q "$m" "$LOG" || { echo "MISS $m"; PASS=0; }
done
grep -q "GUEST-TEST OK: aira-init status" "$LOG" || { echo "MISS service status"; PASS=0; }
grep -q "GUEST AUTOTEST PASS" "$LOG" || { echo "MISS guest pass"; PASS=0; }
if grep -qi "Kernel panic" "$LOG"; then echo "panic!"; PASS=0; fi
cp -f "$LOG" "$OUTDIR/last.log"
[ "$PASS" = "1" ] && { echo "SERVICES TEST PASS"; exit 0; } || { echo "SERVICES TEST FAIL (see $LOG)"; exit 1; }
