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
# Seed minimal identity files if absent (also created by userspace setup; keep idempotent)
[ -f "$STAGE/etc/os-release" ] || cat > "$STAGE/etc/os-release" <<'EOF'
NAME="AiraOS-Octave"
VERSION="0.1.0"
ID=aira-octave
VERSION_ID=0.1.0
PRETTY_NAME="AiraOS-Octave 0.1.0 (Linux 7.2.2)"
HOME_URL="https://github.com/manansulya01/Aira-Octave"
EOF
[ -f "$STAGE/etc/hostname" ] || echo "aira-octave" > "$STAGE/etc/hostname"

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
