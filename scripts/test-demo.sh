#!/usr/bin/env bash
# Demo-mode test: boot with aira_demo=1, verify live tour markers, expect shell hang (timeout kill).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/demo"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/demo-$TS.log"
bash "$ROOT/scripts/boot-qemu.sh" --timeout 40 --log "$LOG" --append "aira_demo=1"
PASS=1
for m in "Linux version" "AiraOS userspace ready" "live demo" "AiraOS-Octave" "Demo complete"; do
  grep -qi "$m" "$LOG" || { echo "MISS $m"; PASS=0; }
done
grep -qi "Kernel panic" "$LOG" && { echo "panic!"; PASS=0; } || true
cp -f "$LOG" "$OUTDIR/last.log"
[ "$PASS" = "1" ] && { echo "DEMO TEST PASS"; exit 0; } || { echo "DEMO TEST FAIL (see $LOG)"; exit 1; }
