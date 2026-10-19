#!/usr/bin/env bash
# Build persistent ext4 rootfs image from rootfs/ staging dir.
# v1: initramfs remains root; image mounted at /persist (no pivot).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/build"
mkdir -p "$OUTDIR" || { echo "ERROR: cannot create build log directory"; exit 1; }
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/rootfs-build-$TS.log"
STAGE="$ROOT/rootfs"
IMG="$ROOT/aira-rootfs.img"
SIZE_M="${1:-256}"
TMPDIR_BUILD=""

cleanup() {
  if [ -n "$TMPDIR_BUILD" ] && [ -d "$TMPDIR_BUILD" ]; then
    rm -rf -- "$TMPDIR_BUILD"
  fi
}
trap cleanup EXIT HUP INT TERM

echo "LOG=$LOG"
{
  echo "TS=$TS SIZE_M=$SIZE_M"
  git rev-parse HEAD
  ls -R "$STAGE" 2>/dev/null | head -n 100 || echo "(no rootfs/ staging yet)"
} | tee "$LOG"

# Reject malformed sizes before touching the existing image.
if [[ ! "$SIZE_M" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: image size must be a positive whole number of MiB; got '$SIZE_M'." | tee -a "$LOG"
  exit 2
fi
if [ ! -d "$STAGE" ]; then
  echo "ERROR: rootfs staging directory is missing: $STAGE" | tee -a "$LOG"
  exit 1
fi
if ! command -v mkfs.ext4 >/dev/null 2>&1; then
  echo "ERROR: mkfs.ext4 not found; install e2fsprogs (>= 1.46 recommended)." | tee -a "$LOG"
  exit 1
fi

mkdir -p "$STAGE/etc/aira" "$STAGE/home/aira" "$STAGE/var/log/airaos" "$STAGE/var/lib/airapkg" "$STAGE/persist" "$STAGE/opt/aira/bin" "$STAGE/usr/share/aira" || {
  echo "ERROR: could not prepare rootfs staging directories." | tee -a "$LOG"
  exit 1
}
# Identity single-source: initramfs/etc is canonical; always sync into staging.
for f in os-release hostname motd; do
  if [ -f "$ROOT/initramfs/etc/$f" ]; then
    cp -f "$ROOT/initramfs/etc/$f" "$STAGE/etc/$f" || {
      echo "ERROR: failed to sync initramfs/etc/$f into rootfs staging." | tee -a "$LOG"
      exit 1
    }
  fi
done

# Build in a private directory on the same filesystem as IMG. The final rename
# is atomic; any mkfs/validation failure leaves the previous working image intact.
TMPDIR_BUILD="$(mktemp -d "$ROOT/.aira-rootfs-build.XXXXXX")" || {
  echo "ERROR: could not create temporary build directory." | tee -a "$LOG"
  exit 1
}
TMP_IMG="$TMPDIR_BUILD/aira-rootfs.img"
echo "TEMP_IMAGE=$TMP_IMG" | tee -a "$LOG"

if ! mkfs.ext4 -d "$STAGE" -L AIRA_ROOT "$TMP_IMG" "${SIZE_M}M" >>"$LOG" 2>&1; then
  echo "ERROR: mkfs.ext4 failed; existing image was not changed (see $LOG)." | tee -a "$LOG"
  exit 1
fi
if [ ! -s "$TMP_IMG" ]; then
  echo "ERROR: mkfs.ext4 reported success but produced no image; existing image was not changed." | tee -a "$LOG"
  exit 1
fi
if ! command -v file >/dev/null 2>&1 || ! file "$TMP_IMG" | tee -a "$LOG" | grep -Eqi 'ext[234] filesystem data'; then
  echo "ERROR: generated image failed filesystem type validation; existing image was not changed." | tee -a "$LOG"
  exit 1
fi
if ! command -v sha256sum >/dev/null 2>&1; then
  echo "ERROR: sha256sum is required to record image integrity; existing image was not changed." | tee -a "$LOG"
  exit 1
fi

ls -lh "$TMP_IMG" | tee -a "$LOG"
sha256sum "$TMP_IMG" | tee -a "$LOG"
# TMP_IMG and IMG are on the same filesystem, so mv replaces the destination atomically.
if ! mv -f -- "$TMP_IMG" "$IMG"; then
  echo "ERROR: could not atomically publish rootfs image; existing image should remain intact." | tee -a "$LOG"
  exit 1
fi
echo "ROOTFS BUILD PASS: $IMG" | tee -a "$LOG"
