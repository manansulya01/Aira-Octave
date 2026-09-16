#!/usr/bin/env bash
# Reproducible initramfs build from initramfs/ source. Verifies contents.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/build"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/initramfs-build-$TS.log"
SRC="$ROOT/initramfs"
OUT="$ROOT/initramfs.cpio"

echo "LOG=$LOG"
{
  echo "TS=$TS"
  git rev-parse HEAD
  ls -R "$SRC"
} | tee "$LOG"

if [ ! -x "$SRC/init" ]; then echo "ERROR: $SRC/init missing/executable" | tee -a "$LOG"; exit 1; fi
if [ ! -f "$SRC/bin/busybox" ]; then echo "ERROR: $SRC/bin/busybox missing" | tee -a "$LOG"; exit 1; fi

# Build to temp, verify, then replace (keep .bak)
TMP="$OUTDIR/initramfs-$TS.cpio"
(
  cd "$SRC" || exit 1
  find . -print0 | cpio --format=newc --create --null > "$TMP"
) >>"$LOG" 2>&1 || { echo "ERROR: cpio failed"; exit 1; }

echo "--- new image contents (first 50) ---" | tee -a "$LOG"
cpio -t < "$TMP" 2>/dev/null | head -n 50 | tee -a "$LOG"
for need in init bin/busybox bin/sh; do
  if cpio -t < "$TMP" 2>/dev/null | grep -qx "$need"; then
    echo "CHECK $need OK" | tee -a "$LOG"
  else
    # allow ./ prefix variant
    if cpio -t < "$TMP" 2>/dev/null | grep -qx "./$need"; then
      echo "CHECK $need OK (./ prefix)" | tee -a "$LOG"
    else
      echo "ERROR: $need missing in new initramfs" | tee -a "$LOG"; exit 1
    fi
  fi
done

ls -lh "$TMP" | tee -a "$LOG"
sha256sum "$TMP" | tee -a "$LOG"
if [ -f "$OUT" ]; then cp -f "$OUT" "$OUT.bak-$TS"; echo "backup: $OUT.bak-$TS" | tee -a "$LOG"; fi
cp -f "$TMP" "$OUT"
echo "INITRAMFS BUILD PASS: $OUT"
