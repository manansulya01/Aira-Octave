#!/usr/bin/env bash
# Build persistent ext4 rootfs image from rootfs/ staging dir.
# v1: initramfs remains root; image mounted at /persist (no pivot).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/build"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/rootfs-build-$TS.log"
STAGE="$ROOT/rootfs"
IMG="$ROOT/aira-rootfs.img"
SIZE_M="${1:-256}"

echo "LOG=$LOG"
{
  echo "TS=$TS SIZE_M=$SIZE_M"
  git rev-parse HEAD
  ls -R "$STAGE" 2>/dev/null | head -n 100 || echo "(no rootfs/ staging yet)"
} | tee "$LOG"

mkdir -p "$STAGE/etc/aira" "$STAGE/home/aira" "$STAGE/var/log/airaos" "$STAGE/var/lib/airapkg" "$STAGE/persist" "$STAGE/opt/aira/bin" "$STAGE/usr/share/aira"
# Identity single-source: initramfs/etc is canonical; always sync into staging.
for f in os-release hostname motd; do
  [ -f "$ROOT/initramfs/etc/$f" ] && cp -f "$ROOT/initramfs/etc/$f" "$STAGE/etc/$f"
done

rm -f "$IMG"
set +e
mkfs.ext4 -d "$STAGE" -L AIRA_ROOT "$IMG" "${SIZE_M}M" >>"$LOG" 2>&1
RC=$?
set -u
if [ $RC -ne 0 ]; then echo "ERROR: mkfs.ext4 -d failed (see $LOG). Need e2fsprogs>=1.46."; exit 1; fi
ls -lh "$IMG" | tee -a "$LOG"
sha256sum "$IMG" | tee -a "$LOG"
file "$IMG" | tee -a "$LOG"
echo "ROOTFS BUILD PASS: $IMG"
