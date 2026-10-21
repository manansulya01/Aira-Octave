#!/usr/bin/env bash
# GUI test: boot with rootfs drive, run in-guest Xvfb desktop + apps.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/gui"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/gui-$TS.log"
IMG="$ROOT/aira-rootfs.img"
[ -f "$IMG" ] || { echo "building rootfs (need GUI)"; bash "$ROOT/scripts/build-gui.sh" || exit 1; bash "$ROOT/scripts/build-rootfs.sh" 512 || exit 1; }
bash "$ROOT/scripts/boot-qemu.sh" --timeout 280 --log "$LOG" --drive "$IMG" --mem 1G --audio --append "aira_autotest=1 aira_guitest=1 aira_audiotest=1"
PASS=1
grep -q "GUEST AUTOTEST PASS" "$LOG" || { echo "MISS guest autotest pass"; PASS=0; }
if grep -q "aira_guitest=1" "$LOG" 2>/dev/null; then echo "INFO guitest flag seen"; fi
if grep -q "GUI TEST PASS" "$LOG"; then echo "GUI markers OK";
else echo "MISS GUI TEST PASS"; PASS=0; fi
if grep -q "AUDIO TEST PASS" "$LOG"; then echo "Audio markers OK";
else echo "MISS AUDIO TEST PASS"; PASS=0; fi
if grep -qi "Kernel panic" "$LOG"; then PASS=0; fi
cp -f "$LOG" "$OUTDIR/last.log"
[ "$PASS" = "1" ] && { echo "GUI TEST PASS"; exit 0; } || { echo "GUI TEST FAIL (see $LOG)"; exit 1; }
