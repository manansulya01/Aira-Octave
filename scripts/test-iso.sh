#!/usr/bin/env bash
# Boot release ISO via grub, verify kernel+userspace markers.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
ARG="${1:-1.5.0}"

# Accept a release version or an ISO path resolving to a direct file in this
# repository's release directory. realpath also blocks traversal and symlink
# escapes; lexical glob checks alone are not sufficient.
if [[ "$ARG" == */* || "$ARG" == *.iso ]]; then
  case "$ARG" in
    "$ROOT"/*) ISO_CANDIDATE="$ARG" ;;
    /*)
      echo "ERROR: absolute ISO path must be inside this repository: $ARG"
      exit 2
      ;;
    *) ISO_CANDIDATE="$ROOT/$ARG" ;;
  esac
  if ! command -v realpath >/dev/null 2>&1; then
    echo "ERROR: realpath is required to validate ISO paths safely."
    exit 2
  fi
  RELEASE_DIR="$(realpath -m -- "$ROOT/release")"
  ISO="$(realpath -m -- "$ISO_CANDIDATE")"
  if [[ "$(dirname -- "$ISO")" != "$RELEASE_DIR" ]]; then
    echo "ERROR: ISO must resolve to a direct file inside $RELEASE_DIR: $ARG"
    exit 2
  fi
  ISO_NAME="${ISO##*/}"
  if [[ "$ISO_NAME" != aira-octave-*.iso ]]; then
    echo "ERROR: ISO filename must be aira-octave-<version>.iso: $ISO_NAME"
    exit 2
  fi
  VER="${ISO_NAME#aira-octave-}"
  VER="${VER%.iso}"
  if [[ -z "$VER" || "$VER" == "$ISO_NAME" || ! "$VER" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "ERROR: invalid release ISO filename: $ISO_NAME"
    exit 2
  fi
else
  VER="$ARG"
  if [[ ! "$VER" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "ERROR: invalid release version: $VER"
    exit 2
  fi
  ISO="$ROOT/release/aira-octave-$VER.iso"
fi
OUTDIR="$ROOT/logs/final-completion/release"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/iso-boot-$VER-$TS.log"
[ -s "$ISO" ] || { echo "ERROR: ISO missing or empty: $ISO"; exit 2; }
# The ISO carries boot files but cannot expose its embedded rootfs file as a
# writable block device. Attach the companion image to test persistent boot.
ROOTFS="$ROOT/release/aira-octave-$VER/aira-rootfs.img"
[ -s "$ROOTFS" ] || { echo "ERROR: companion rootfs image missing or empty: $ROOTFS"; exit 2; }
echo "Booting $ISO with companion rootfs $ROOTFS (grub, 60s)"
set +e
timeout --foreground 60 qemu-system-x86_64 -cdrom "$ISO" -boot d \
  -drive "file=$ROOTFS,if=virtio,format=raw" \
  -m 1024M -nographic -serial stdio -monitor none -no-reboot </dev/null > "$LOG" 2>&1
echo "QEMU done, analyzing $LOG"
set -u
PASS=1
grep -q "Linux version" "$LOG" || { echo "MISS Linux version"; PASS=0; }
grep -q "AiraOS userspace ready" "$LOG" || { echo "MISS userspace"; PASS=0; }
grep -q "\[init\] auto-starting AiraOS desktop (background)" "$LOG" || { echo "MISS default desktop launch request"; PASS=0; }
grep -q "\[init\] /persist mounted from /dev/vda" "$LOG" || { echo "MISS persistent rootfs mount"; PASS=0; }
grep -qi "Kernel panic" "$LOG" && { echo "panic!"; PASS=0; } || true
cp -f "$LOG" "$OUTDIR/iso-last.log"
[ "$PASS" = "1" ] && { echo "ISO BOOT TEST PASS"; exit 0; } || { echo "ISO BOOT TEST FAIL"; exit 1; }
