#!/usr/bin/env bash
# AiraOS-Octave canonical QEMU boot (text mode, serial capture)
# Usage: boot-qemu.sh [--mem 512M] [--timeout 30] [--log PATH] [--append EXTRA] [--drive FILE] [--gpu virtio|std] [--net user|none]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

KERNEL="$ROOT/linux-7.2.2/arch/x86/boot/bzImage"
INITRAMFS="$ROOT/initramfs.cpio"
MEM="512M"
TIMEOUT="30"
LOG=""
APPEND_EXTRA=""
DRIVE=""
GPU="std"
NET="none"
AUDIO="no"

while [ $# -gt 0 ]; do
  case "$1" in
    --mem) MEM="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --log) LOG="$2"; shift 2;;
    --append) APPEND_EXTRA="$2"; shift 2;;
    --drive) DRIVE="$2"; shift 2;;
    --gpu) GPU="$2"; shift 2;;
    --net) NET="$2"; shift 2;;
    --audio) AUDIO="yes"; shift;;
    -h|--help)
      echo "Usage: boot-qemu.sh [--mem 512M] [--timeout 30] [--log PATH] [--append EXTRA] [--drive FILE] [--gpu std|virtio] [--net none|user] [--audio]"
      exit 0;;
    *) echo "ERROR: unknown arg $1" >&2; exit 2;;
  esac
done

if [ ! -f "$KERNEL" ]; then echo "ERROR: kernel missing: $KERNEL" >&2; exit 1; fi
if [ ! -s "$INITRAMFS" ]; then echo "ERROR: initramfs missing: $INITRAMFS" >&2; exit 1; fi
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "ERROR: qemu-system-x86_64 not found" >&2; exit 1; }
command -v timeout >/dev/null 2>&1 || { echo "ERROR: timeout not found" >&2; exit 1; }

APPEND="console=ttyS0 rdinit=/init loglevel=7"
if [ -n "$APPEND_EXTRA" ]; then APPEND="$APPEND $APPEND_EXTRA"; fi

QEMU_ARGS=(-kernel "$KERNEL" -initrd "$INITRAMFS" -append "$APPEND" -m "$MEM" -nographic -no-reboot)
if [ "$GPU" = "virtio" ]; then
  QEMU_ARGS+=(-device virtio-gpu-pci -device virtio-keyboard-pci -device virtio-mouse-pci)
fi
if [ -n "$DRIVE" ]; then
  if [ ! -f "$DRIVE" ]; then echo "ERROR: drive missing: $DRIVE" >&2; exit 1; fi
  QEMU_ARGS+=(-drive "file=$DRIVE,if=virtio,format=raw")
fi
if [ "$NET" = "user" ]; then
  QEMU_ARGS+=(-device virtio-net-pci,netdev=n0 -netdev "user,id=n0")
fi
if [ "$AUDIO" = "yes" ]; then
  # Use QEMU's discard backend: the guest gets a real HDA device without
  # requiring host speakers or an audio server in CI.
  QEMU_ARGS+=(-audiodev none,id=audio0 -device intel-hda -device hda-output,audiodev=audio0)
fi

echo "AIRA-QEMU kernel=$KERNEL initramfs=$INITRAMFS mem=$MEM timeout=${TIMEOUT}s gpu=$GPU net=$NET audio=$AUDIO"
echo "QEMU: qemu-system-x86_64 ${QEMU_ARGS[*]}"

if [ -z "$LOG" ]; then
  exec qemu-system-x86_64 "${QEMU_ARGS[@]}"
else
  mkdir -p "$(dirname "$LOG")"
  set +e
  timeout --foreground "$TIMEOUT" qemu-system-x86_64 "${QEMU_ARGS[@]}" -serial stdio -monitor none </dev/null > "$LOG" 2>&1
  RC=$?
  echo "QEMU_EXIT=$RC log=$LOG"
  # 124 = timeout killed (expected: guest idles at shell). 0/1 may occur on early exit.
  exit 0
fi
