#!/usr/bin/env bash
# AiraOS-Octave visible-desktop boot (graphical QEMU window).
#
# Shows the real Aira JWM desktop in the QEMU GTK window using virtio-vga
# (the kernel+X stack already support it: DRM_VIRTIO_GPU + modesetting).
# Plain `-vga std` (Bochs VBE) has no driver in this kernel/X stack, so it
# can never show the desktop; `-vga virtio` is the same GTK window, just a
# GPU the guest actually drives.
#
# Usage: boot-gui.sh [--mem 1G] [--timeout 0] [--log PATH] [--append EXTRA]
#                    [--drive FILE] [--display gtk|vnc|sdl|none] [--net user|none]
#   --timeout 0 (default) = run interactively, no timeout.
#   --display none = headless (guest still starts the VISIBLE Xorg backend on
#     the virtual GPU; use for automated verification via screendump/xwd).
#   Serial recovery shell stays on stdio in all modes.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

KERNEL="$ROOT/linux-7.2.2/arch/x86/boot/bzImage"
INITRAMFS="$ROOT/initramfs.cpio"
MEM="1G"
TIMEOUT="0"
LOG=""
APPEND_EXTRA=""
DRIVE="$ROOT/aira-rootfs.img"
DISPLAY_BE="gtk,gl=off"
NET="none"

while [ $# -gt 0 ]; do
  case "$1" in
    --mem) MEM="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --log) LOG="$2"; shift 2;;
    --append) APPEND_EXTRA="$2"; shift 2;;
    --drive) DRIVE="$2"; shift 2;;
    --display) DISPLAY_BE="$2"; shift 2;;
    --net) NET="$2"; shift 2;;
    -h|--help)
      echo "Usage: boot-gui.sh [--mem 1G] [--timeout 0] [--log PATH] [--append EXTRA] [--drive FILE] [--display gtk,gl=off|vnc=:0|none] [--net none|user]"
      exit 0;;
    *) echo "ERROR: unknown arg $1" >&2; exit 2;;
  esac
done

[ -f "$KERNEL" ] || { echo "ERROR: kernel missing: $KERNEL" >&2; exit 1; }
[ -s "$INITRAMFS" ] || { echo "ERROR: initramfs missing: $INITRAMFS" >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "ERROR: qemu-system-x86_64 not found" >&2; exit 1; }
if [ "$DRIVE" != "none" ] && [ ! -f "$DRIVE" ]; then echo "ERROR: drive missing: $DRIVE" >&2; exit 1; fi

APPEND="console=ttyS0 rdinit=/init loglevel=7 aira_gui=1"
if [ -n "$APPEND_EXTRA" ]; then APPEND="$APPEND $APPEND_EXTRA"; fi

QEMU_ARGS=(-kernel "$KERNEL" -initrd "$INITRAMFS" -append "$APPEND" -m "$MEM" -no-reboot)
# Visible GPU the guest kernel already drives (DRM_VIRTIO_GPU + Xorg modesetting).
QEMU_ARGS+=(-vga virtio)
QEMU_ARGS+=(-device virtio-keyboard-pci -device virtio-mouse-pci)
if [ "$DRIVE" != "none" ]; then
  QEMU_ARGS+=(-drive "file=$DRIVE,if=virtio,format=raw")
fi
if [ "$NET" = "user" ]; then
  QEMU_ARGS+=(-device virtio-net-pci,netdev=n0 -netdev "user,id=n0")
fi
QEMU_ARGS+=(-display "$DISPLAY_BE")
# Serial recovery shell always available (stdio, or log file in batch mode).
QEMU_ARGS+=(-serial stdio -monitor none)

echo "AIRA-GUI kernel=$KERNEL initramfs=$INITRAMFS mem=$MEM display=$DISPLAY_BE drive=$DRIVE"
echo "QEMU: qemu-system-x86_64 ${QEMU_ARGS[*]}"

if [ "$TIMEOUT" = "0" ] && [ -z "$LOG" ]; then
  exec qemu-system-x86_64 "${QEMU_ARGS[@]}"
else
  mkdir -p "$(dirname "$LOG" 2>/dev/null || echo .)" 2>/dev/null
  [ -n "$LOG" ] && mkdir -p "$(dirname "$LOG")"
  command -v timeout >/dev/null 2>&1 || { echo "ERROR: timeout not found" >&2; exit 1; }
  set +e
  if [ -n "$LOG" ]; then
    timeout --foreground "$TIMEOUT" qemu-system-x86_64 "${QEMU_ARGS[@]}" </dev/null > "$LOG" 2>&1
  else
    timeout --foreground "$TIMEOUT" qemu-system-x86_64 "${QEMU_ARGS[@]}" </dev/null
  fi
  RC=$?
  echo "QEMU_EXIT=$RC log=${LOG:-<stdio>}"
  exit 0
fi
