#!/usr/bin/env bash
# Persistence test: build rootfs.img, boot twice with same drive, verify file remains.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/storage"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
IMG="$ROOT/aira-rootfs.img"
if [ ! -f "$IMG" ]; then
  echo "building $IMG"
  bash "$ROOT/scripts/build-rootfs.sh" 256 || exit 1
fi
LOG1="$OUTDIR/storage-boot1-$TS.log"
LOG2="$OUTDIR/storage-boot2-$TS.log"
echo "=== boot1 (create marker) ==="
bash "$ROOT/scripts/boot-qemu.sh" --timeout 220 --log "$LOG1" --drive "$IMG" --append "aira_autotest=1"
grep -q "GUEST-TEST OK: persist write" "$LOG1" || { echo "FAIL boot1 persist write (see $LOG1)"; exit 1; }
echo "=== boot2 (verify persists) ==="
bash "$ROOT/scripts/boot-qemu.sh" --timeout 220 --log "$LOG2" --drive "$IMG" --append "aira_autotest=1"
if grep -q "GUEST-TEST OK: persist-exists" "$LOG2"; then
  echo "STORAGE TEST PASS (persistence verified)"
  cp -f "$LOG2" "$OUTDIR/last.log"
  exit 0
else
  echo "STORAGE TEST FAIL: marker did not persist (see $LOG2)"
  exit 1
fi
