#!/usr/bin/env bash

set +e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

KERNEL="$ROOT/linux-7.2.2/arch/x86/boot/bzImage"
INITRAMFS="$ROOT/initramfs.cpio"

if [ ! -f "$KERNEL" ]; then
    echo "ERROR: kernel missing"
    exit 1
fi

if [ ! -s "$INITRAMFS" ]; then
    echo "ERROR: initramfs missing"
    exit 1
fi

echo "AIRA OCTAVE QEMU BOOT"
echo "Kernel: $KERNEL"
echo "Initramfs: $INITRAMFS"

exec qemu-system-x86_64 \
    -kernel "$KERNEL" \
    -initrd "$INITRAMFS" \
    -append "console=ttyS0 rdinit=/init" \
    -m 512M \
    -nographic \
    -serial mon:stdio \
    -no-reboot \
    -no-shutdown
