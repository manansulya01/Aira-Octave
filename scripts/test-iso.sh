#!/usr/bin/env bash
# Boot release ISO via grub, verify kernel+userspace markers.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
VER="${1:-0.1.0}"
ISO="$ROOT/release/aira-octave-$VER.iso"
OUTDIR="$ROOT/logs/final-completion/release"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/iso-boot-$VER-$TS.log"
[ -f "$ISO" ] || { echo "ERROR: ISO missing $ISO"; exit 2; }
echo "Booting $ISO (grub, 60s)"
set +e
timeout 60 qemu-system-x86_64 -cdrom "$ISO" -boot d -m 512M -nographic -no-reboot > "$LOG" 2>&1
echo "QEMU done, analyzing $LOG"
set -u
PASS=1
grep -q "Linux version" "$LOG" || { echo "MISS Linux version"; PASS=0; }
grep -q "AiraOS userspace ready" "$LOG" || { echo "MISS userspace"; PASS=0; }
grep -qi "Kernel panic" "$LOG" && { echo "panic!"; PASS=0; } || true
cp -f "$LOG" "$OUTDIR/iso-last.log"
[ "$PASS" = "1" ] && { echo "ISO BOOT TEST PASS"; exit 0; } || { echo "ISO BOOT TEST FAIL"; exit 1; }
