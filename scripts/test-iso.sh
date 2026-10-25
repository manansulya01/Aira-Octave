#!/usr/bin/env bash
# Boot release ISO via grub, verify kernel+userspace markers.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
VER="${1:-1.5.0}"
ISO="$ROOT/release/aira-octave-$VER.iso"
OUTDIR="$ROOT/logs/final-completion/release"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/iso-boot-$VER-$TS.log"
[ -s "$ISO" ] || { echo "ERROR: ISO missing or empty: $ISO"; exit 2; }
# The ISO contains the kernel/initramfs and the rootfs image as a file, but
# firmware does not expose that file as a writable block device. Attach the
# companion release image as a second virtual disk so this smoke test verifies
# the real persistent-userspace boot path, not only the minimal initramfs.
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
grep -q "\[init\] /persist mounted from /dev/vda" "$LOG" || { echo "MISS persistent rootfs mount"; PASS=0; }
grep -qi "Kernel panic" "$LOG" && { echo "panic!"; PASS=0; } || true
cp -f "$LOG" "$OUTDIR/iso-last.log"
[ "$PASS" = "1" ] && { echo "ISO BOOT TEST PASS"; exit 0; } || { echo "ISO BOOT TEST FAIL"; exit 1; }
