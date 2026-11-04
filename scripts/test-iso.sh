#!/usr/bin/env bash
# Boot release ISO via grub, verify kernel+userspace markers.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
ARG="${1:-1.5.0}"

# Accept a release version or a direct ISO entry in this repository's
# release/ directory. Reject nested paths and traversal components.
if [[ "$ARG" == */* || "$ARG" == *.iso ]]; then
  if [[ "$ARG" == "$ROOT/release/"* ]]; then
    ISO_NAME="${ARG#"$ROOT/release/"}"
    ISO="$ARG"
  elif [[ "$ARG" == release/* ]]; then
    ISO_NAME="${ARG#release/}"
    ISO="$ROOT/release/$ISO_NAME"
  else
    echo "ERROR: ISO path must be a direct file in this repository's release/ directory: $ARG"
    exit 2
  fi
  if [[ "$ISO_NAME" == */* || "$ISO_NAME" != aira-octave-*.iso ]]; then
    echo "ERROR: ISO path must name release/aira-octave-<version>.iso directly: $ARG"
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
