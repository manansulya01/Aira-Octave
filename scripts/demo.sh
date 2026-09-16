#!/usr/bin/env bash
# AiraOS-Octave live demo: boots the release (or tree) with the demo tour.
# Usage: scripts/demo.sh [--iso] [--gui] — streams serial to your terminal.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
MODE="tree"
GUI="no"
for a in "$@"; do case "$a" in --iso) MODE="iso";; --gui) GUI="yes";; esac; done
if [ "$MODE" = "iso" ]; then
  ISO="$(ls -t release/*.iso 2>/dev/null | head -n 1)"
  [ -n "$ISO" ] || { echo "no release ISO (run build-release.sh)"; exit 2; }
  echo "=== AiraOS demo from ISO: $ISO ==="
  echo "(Interact: serial console. Exit: Ctrl-A X)"
  if [ "$GUI" = "yes" ]; then
    qemu-system-x86_64 -cdrom "$ISO" -boot d -m 1G -drive file=aira-rootfs.img,if=virtio,format=raw -nographic -no-reboot -append "console=ttyS0 rdinit=/init aira_demo=1"
  else
    timeout 120 qemu-system-x86_64 -cdrom "$ISO" -boot d -m 512M -nographic -no-reboot
  fi
else
  echo "=== AiraOS demo from tree (text + demo tour) ==="
  if [ "$GUI" = "yes" ]; then
    bash scripts/boot-qemu.sh --mem 1G --timeout 120 --drive aira-rootfs.img --append "aira_demo=1"
  else
    bash scripts/boot-qemu.sh --mem 512M --timeout 120 --append "aira_demo=1"
  fi
fi
