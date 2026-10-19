#!/usr/bin/env bash
# Build AiraOS-Octave release: versioned dir + tarball + bootable ISO + SHA256 + notes.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
VER="${1:-1.5.0}"
if [[ ! "$VER" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "ERROR: version must contain only letters, numbers, dots, underscores, and hyphens."
  exit 2
fi
REL="$ROOT/release/aira-octave-$VER"
RELEASE_DIR="$ROOT/release"
OUTDIR="$ROOT/logs/final-completion/release"
mkdir -p "$OUTDIR" "$RELEASE_DIR" || { echo "ERROR: cannot create release/log directories"; exit 1; }
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/release-$VER-$TS.log"
TMPDIR_BUILD=""

cleanup() {
  if [ -n "$TMPDIR_BUILD" ] && [ -d "$TMPDIR_BUILD" ]; then
    rm -rf -- "$TMPDIR_BUILD"
  fi
}
trap cleanup EXIT HUP INT TERM

{
  echo "TS=$TS VER=$VER"
  git rev-parse HEAD
} | tee "$LOG"

# Fail early rather than printing a successful release when a required artifact
# cannot be generated. Keep any previous published ISO/tarball/checksum untouched.
for need in \
  "linux-7.2.2/arch/x86/boot/bzImage" \
  "initramfs.cpio" \
  "aira-rootfs.img" \
  "configs/airaos-octave-x86_64.config" \
  "scripts/boot-qemu.sh"; do
  if [ ! -f "$need" ]; then
    echo "ERROR: required release input missing: $need" | tee -a "$LOG"
    exit 1
  fi
done
for tool in grub-mkrescue tar sha256sum; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: required release tool missing: $tool" | tee -a "$LOG"
    exit 1
  fi
done

mkdir -p "$REL/boot/grub" || { echo "ERROR: cannot create $REL"; exit 1; }
cp -f linux-7.2.2/arch/x86/boot/bzImage "$REL/boot/bzImage" || exit 1
cp -f initramfs.cpio "$REL/boot/initramfs.cpio" || exit 1
cp -f aira-rootfs.img "$REL/aira-rootfs.img" || exit 1
cp -f configs/airaos-octave-x86_64.config "$REL/kernel-config.txt" || exit 1
cp -f scripts/boot-qemu.sh "$REL/boot-qemu.sh" || exit 1

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
cat > "$REL/RELEASE_NOTES.txt" <<EOF
AiraOS-Octave $VER (Linux 7.2.2, x86_64)
Build: $TS UTC
Kernel: bzImage (see kernel-config.txt)
Userspace: BusyBox-based initramfs plus AiraOS-Octave services and optional X11/JWM desktop
Boot (direct): qemu-system-x86_64 -kernel boot/bzImage -initrd boot/initramfs.cpio -append "console=ttyS0 rdinit=/init loglevel=7" -m 512M -nographic -no-reboot
Boot (ISO): qemu-system-x86_64 -cdrom aira-octave-$VER.iso -m 512M -nographic -no-reboot
GUI/persist: add -drive file=aira-rootfs.img,if=virtio,format=raw (desktop via aira-session)
Tests: scripts/test-all.sh (run on the build host; consult its log for PASS/FAIL/SKIP)
Docs: docs/ (BUILD, BOOT, TESTING, ARCHITECTURE, USER_GUIDE, and more)
EOF

TMPDIR_BUILD="$(mktemp -d "$RELEASE_DIR/.aira-release-$VER.XXXXXX")" || {
  echo "ERROR: could not create temporary release workspace." | tee -a "$LOG"
  exit 1
}
ISO_TMP="$TMPDIR_BUILD/aira-octave-$VER.iso"
TAR_TMP="$TMPDIR_BUILD/aira-octave-$VER.tar.gz"
SUM_TMP="$TMPDIR_BUILD/aira-octave-$VER.sha256"
ISO="$RELEASE_DIR/aira-octave-$VER.iso"
TAR="$RELEASE_DIR/aira-octave-$VER.tar.gz"
SUM="$RELEASE_DIR/aira-octave-$VER.sha256"

echo "Building ISO to temporary path: $ISO_TMP" | tee -a "$LOG"
if ! grub-mkrescue -o "$ISO_TMP" "$REL" >>"$LOG" 2>&1; then
  echo "ERROR: ISO generation failed; existing published release artifacts were not replaced (see $LOG)." | tee -a "$LOG"
  exit 1
fi
if [ ! -s "$ISO_TMP" ]; then
  echo "ERROR: ISO generator returned success but produced an empty file." | tee -a "$LOG"
  exit 1
fi

echo "Building tarball to temporary path: $TAR_TMP" | tee -a "$LOG"
if ! tar -czf "$TAR_TMP" -C "$RELEASE_DIR" "aira-octave-$VER" >>"$LOG" 2>&1; then
  echo "ERROR: tarball generation failed; existing published release artifacts were not replaced (see $LOG)." | tee -a "$LOG"
  exit 1
fi
if [ ! -s "$TAR_TMP" ]; then
  echo "ERROR: tar returned success but produced an empty tarball." | tee -a "$LOG"
  exit 1
fi

# Generate checksums for exactly the artifacts that will be published.
if ! {
  sha256sum "$TAR_TMP" | awk -v name="aira-octave-$VER.tar.gz" '{print $1 "  " name}'
  sha256sum "$ISO_TMP" | awk -v name="aira-octave-$VER.iso" '{print $1 "  " name}'
  sha256sum "$REL/boot/bzImage" | awk -v name="aira-octave-$VER/boot/bzImage" '{print $1 "  " name}'
  sha256sum "$REL/boot/initramfs.cpio" | awk -v name="aira-octave-$VER/boot/initramfs.cpio" '{print $1 "  " name}'
  sha256sum "$REL/aira-rootfs.img" | awk -v name="aira-octave-$VER/aira-rootfs.img" '{print $1 "  " name}'
} > "$SUM_TMP"; then
  echo "ERROR: checksum generation failed; existing published release artifacts were not replaced." | tee -a "$LOG"
  exit 1
fi
[ -s "$SUM_TMP" ] || { echo "ERROR: checksum file is empty." | tee -a "$LOG"; exit 1; }

# Publish only after all required outputs have been generated successfully.
mv -f -- "$ISO_TMP" "$ISO" || { echo "ERROR: could not publish ISO"; exit 1; }
mv -f -- "$TAR_TMP" "$TAR" || { echo "ERROR: could not publish tarball"; exit 1; }
mv -f -- "$SUM_TMP" "$SUM" || { echo "ERROR: could not publish checksums"; exit 1; }

{
  echo "--- published artifacts ---"
  ls -lh "$ISO" "$TAR" "$SUM" "$REL/boot/bzImage" "$REL/boot/initramfs.cpio" "$REL/aira-rootfs.img"
  echo "--- checksums ---"
  cat "$SUM"
  echo "RELEASE BUILD PASS: $REL"
} | tee -a "$LOG"
