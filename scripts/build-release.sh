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

# Build the complete versioned directory privately. Do not touch the previous
# release directory until ISO, tarball, and checksums have all been generated.
TMPDIR_BUILD="$(mktemp -d "$RELEASE_DIR/.aira-release-$VER.XXXXXX")" || {
  echo "ERROR: could not create temporary release workspace." | tee -a "$LOG"
  exit 1
}
STAGE_REL="$TMPDIR_BUILD/aira-octave-$VER"
mkdir -p "$STAGE_REL/boot/grub" || { echo "ERROR: cannot create staging release directory"; exit 1; }
cp -f linux-7.2.2/arch/x86/boot/bzImage "$STAGE_REL/boot/bzImage" || exit 1
cp -f initramfs.cpio "$STAGE_REL/boot/initramfs.cpio" || exit 1
cp -f aira-rootfs.img "$STAGE_REL/aira-rootfs.img" || exit 1
cp -f configs/airaos-octave-x86_64.config "$STAGE_REL/kernel-config.txt" || exit 1
cp -f scripts/boot-qemu.sh "$STAGE_REL/boot-qemu.sh" || exit 1

cat > "$STAGE_REL/boot/grub/grub.cfg" <<'EOF'
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
cat > "$STAGE_REL/RELEASE_NOTES.txt" <<EOF
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
ISO_TMP="$TMPDIR_BUILD/aira-octave-$VER.iso"
TAR_TMP="$TMPDIR_BUILD/aira-octave-$VER.tar.gz"
SUM_TMP="$TMPDIR_BUILD/aira-octave-$VER.sha256"
ISO="$RELEASE_DIR/aira-octave-$VER.iso"
TAR="$RELEASE_DIR/aira-octave-$VER.tar.gz"
SUM="$RELEASE_DIR/aira-octave-$VER.sha256"

echo "Building ISO to temporary path: $ISO_TMP" | tee -a "$LOG"
if ! grub-mkrescue -o "$ISO_TMP" "$STAGE_REL" >>"$LOG" 2>&1; then
  echo "ERROR: ISO generation failed; existing published release artifacts were not replaced (see $LOG)." | tee -a "$LOG"
  exit 1
fi
if [ ! -s "$ISO_TMP" ]; then
  echo "ERROR: ISO generator returned success but produced an empty file." | tee -a "$LOG"
  exit 1
fi

echo "Building tarball to temporary path: $TAR_TMP" | tee -a "$LOG"
if ! tar -czf "$TAR_TMP" -C "$TMPDIR_BUILD" "aira-octave-$VER" >>"$LOG" 2>&1; then
  echo "ERROR: tarball generation failed; existing published release artifacts were not replaced (see $LOG)." | tee -a "$LOG"
  exit 1
fi
if [ ! -s "$TAR_TMP" ]; then
  echo "ERROR: tar returned success but produced an empty tarball." | tee -a "$LOG"
  exit 1
fi

# Generate checksums for exactly the artifacts that will be published.
write_checksum() {
  local path="$1" name="$2" result
  result="$(sha256sum "$path")" || return 1
  printf '%s  %s\n' "${result%% *}" "$name"
}
if ! {
  write_checksum "$TAR_TMP" "aira-octave-$VER.tar.gz" &&
  write_checksum "$ISO_TMP" "aira-octave-$VER.iso" &&
  write_checksum "$STAGE_REL/boot/bzImage" "aira-octave-$VER/boot/bzImage" &&
  write_checksum "$STAGE_REL/boot/initramfs.cpio" "aira-octave-$VER/boot/initramfs.cpio" &&
  write_checksum "$STAGE_REL/aira-rootfs.img" "aira-octave-$VER/aira-rootfs.img"
} > "$SUM_TMP"; then
  echo "ERROR: checksum generation failed; existing published release artifacts were not replaced." | tee -a "$LOG"
  exit 1
fi
[ -s "$SUM_TMP" ] || { echo "ERROR: checksum file is empty." | tee -a "$LOG"; exit 1; }

# Publish as a rollback-capable transaction. Copy backups first so a backup
# failure never moves or deletes a previously published artifact.
REL_BACKUP="$TMPDIR_BUILD/previous-release-dir"
ISO_BACKUP="$TMPDIR_BUILD/previous-release.iso"
TAR_BACKUP="$TMPDIR_BUILD/previous-release.tar.gz"
SUM_BACKUP="$TMPDIR_BUILD/previous-release.sha256"
HAD_REL=0; HAD_ISO=0; HAD_TAR=0; HAD_SUM=0
if [ -e "$REL" ] || [ -L "$REL" ]; then
  cp -a -- "$REL" "$REL_BACKUP" || { echo "ERROR: could not back up previous release directory; nothing published" | tee -a "$LOG"; exit 1; }
  HAD_REL=1
fi
if [ -e "$ISO" ] || [ -L "$ISO" ]; then
  cp -a -- "$ISO" "$ISO_BACKUP" || { echo "ERROR: could not back up previous ISO; nothing published" | tee -a "$LOG"; exit 1; }
  HAD_ISO=1
fi
if [ -e "$TAR" ] || [ -L "$TAR" ]; then
  cp -a -- "$TAR" "$TAR_BACKUP" || { echo "ERROR: could not back up previous tarball; nothing published" | tee -a "$LOG"; exit 1; }
  HAD_TAR=1
fi
if [ -e "$SUM" ] || [ -L "$SUM" ]; then
  cp -a -- "$SUM" "$SUM_BACKUP" || { echo "ERROR: could not back up previous checksum manifest; nothing published" | tee -a "$LOG"; exit 1; }
  HAD_SUM=1
fi
rollback_publish() {
  local failed=0
  rm -rf -- "$REL" || failed=1
  [ "$HAD_REL" -eq 0 ] || cp -a -- "$REL_BACKUP" "$REL" || failed=1
  rm -f -- "$ISO" "$TAR" "$SUM" || failed=1
  [ "$HAD_ISO" -eq 0 ] || cp -a -- "$ISO_BACKUP" "$ISO" || failed=1
  [ "$HAD_TAR" -eq 0 ] || cp -a -- "$TAR_BACKUP" "$TAR" || failed=1
  [ "$HAD_SUM" -eq 0 ] || cp -a -- "$SUM_BACKUP" "$SUM" || failed=1
  return "$failed"
}
# Remove the old directory only after a verified backup exists. POSIX mv
# nests a source directory inside an existing non-empty destination directory;
# it does not replace that directory, so explicitly remove the target here.
if ! rm -rf -- "$REL" ||
   ! mv -- "$STAGE_REL" "$REL" ||
   ! mv -- "$ISO_TMP" "$ISO" ||
   ! mv -- "$TAR_TMP" "$TAR" ||
   ! mv -- "$SUM_TMP" "$SUM"; then
  echo "ERROR: release publication failed; restoring previous artifacts" | tee -a "$LOG"
  rollback_publish || echo "CRITICAL: release rollback incomplete; inspect $TMPDIR_BUILD and $LOG" | tee -a "$LOG"
  exit 1
fi

{
  echo "--- published artifacts ---"
  ls -lh "$ISO" "$TAR" "$SUM" "$REL/boot/bzImage" "$REL/boot/initramfs.cpio" "$REL/aira-rootfs.img"
  echo "--- checksums ---"
  cat "$SUM"
  echo "RELEASE BUILD PASS: $REL"
} | tee -a "$LOG"
