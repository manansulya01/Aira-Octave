#!/usr/bin/env bash
# Build AiraOS-Octave release: versioned dir + tarball + bootable ISO + SHA256 + notes.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
VER="${1:-1.5.0}"
REL="$ROOT/release/aira-octave-$VER"
OUTDIR="$ROOT/logs/final-completion/release"
mkdir -p "$OUTDIR" "$REL/boot/grub"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/release-$VER-$TS.log"
{
  echo "TS=$TS VER=$VER"
  git rev-parse HEAD
} | tee "$LOG"

[ -f linux-7.2.2/arch/x86/boot/bzImage ] || { echo "ERROR: bzImage missing"; exit 1; }
[ -f initramfs.cpio ] || { echo "ERROR: initramfs missing"; exit 1; }
[ -f aira-rootfs.img ] || { echo "ERROR: rootfs img missing (run build-rootfs.sh)"; exit 1; }

cp -f linux-7.2.2/arch/x86/boot/bzImage "$REL/boot/bzImage"
cp -f initramfs.cpio "$REL/boot/initramfs.cpio"
cp -f aira-rootfs.img "$REL/aira-rootfs.img"
cp -f configs/airaos-octave-x86_64.config "$REL/kernel-config.txt"
cat > "$REL/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0
serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
terminal_input serial
terminal_output serial
menuentry "AiraOS-Octave" {
  linux /boot/bzImage console=ttyS0 rdinit=/init loglevel=7
  initrd /boot/initramfs.cpio
}
menuentry "AiraOS-Octave (autotest)" {
  linux /boot/bzImage console=ttyS0 rdinit=/init loglevel=7 aira_autotest=1
  initrd /boot/initramfs.cpio
}
EOF
cp -f scripts/boot-qemu.sh "$REL/" 2>/dev/null || true
cat > "$REL/RELEASE_NOTES.txt" <<EOF
AiraOS-Octave $VER (Linux 7.2.2, x86_64)
Build: $TS UTC
Kernel: bzImage GZIP PREEMPT_DYNAMIC SMP (see kernel-config.txt)
Userspace: BusyBox + aira + airapkg + services + X11/JWM desktop
Boot (direct): qemu-system-x86_64 -kernel boot/bzImage -initrd boot/initramfs.cpio -append "console=ttyS0 rdinit=/init loglevel=7" -m 512M -nographic -no-reboot
Boot (ISO): qemu-system-x86_64 -cdrom aira-octave-$VER.iso -m 512M -nographic -no-reboot
GUI/persist: add -drive file=aira-rootfs.img,if=virtio,format=raw (desktop via aira-session)
Tests: scripts/test-all.sh (kernel/userspace/services/storage/network/gui)
Docs: docs/ (BUILD BOOT TESTING ARCHITECTURE USER_GUIDE ...)
EOF
# ISO (grub-mkrescue needs xorriso; both present on build host)
if command -v grub-mkrescue >/dev/null 2>&1; then
  grub-mkrescue -o "$ROOT/release/aira-octave-$VER.iso" "$REL" >>"$LOG" 2>&1 || echo "WARN: grub-mkrescue failed (see $LOG)"
else
  echo "WARN: grub-mkrescue missing, skipping ISO"
fi
# tarball + checksums
tar -czf "$ROOT/release/aira-octave-$VER.tar.gz" -C "$ROOT/release" "aira-octave-$VER" >>"$LOG" 2>&1 || exit 1
(cd "$ROOT/release" && sha256sum "aira-octave-$VER.tar.gz" "aira-octave-$VER.iso" "aira-octave-$VER/boot/bzImage" "aira-octave-$VER/boot/initramfs.cpio" "aira-octave-$VER/aira-rootfs.img" > "aira-octave-$VER.sha256" 2>/dev/null) || true
ls -lh "$ROOT/release/" | tee -a "$LOG"
cat "$ROOT/release/aira-octave-$VER.sha256" 2>/dev/null | tee -a "$LOG"
echo "RELEASE BUILD DONE: $REL"
