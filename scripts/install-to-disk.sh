#!/usr/bin/env bash
# Install a built AiraOS-Octave release to a whole BIOS/MBR disk.
# Destructive operation: requires an interactive confirmation, or BOTH
# --yes and --allow-erase for explicitly authorized unattended use.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=""
RELEASE_DIR="$ROOT/release/aira-octave-1.5.0"
ASSUME_YES=0
ALLOW_ERASE=0
TMP=""
TARGET_MNT=""
SOURCE_MNT=""
TARGET_MOUNTED=0
SOURCE_MOUNTED=0

usage() {
  cat <<'EOF'
Usage: sudo scripts/install-to-disk.sh --target /dev/sdX [options]

Options:
  --target DEVICE       Whole target disk (not a partition)
  --release-dir DIR     Built release directory (default: release/aira-octave-1.5.0)
  --yes                 Skip prompt; requires --allow-erase too
  --allow-erase         Explicit acknowledgement that the target disk will be erased
  --help                Show help

This installer creates a DOS/MBR partition table and installs the BIOS/GRUB
boot path. It erases the selected target disk. Back up its contents first.
EOF
}

while (($#)); do
  case "$1" in
    --target) (($# >= 2)) || { echo "ERROR: --target requires a device"; exit 2; }; TARGET="$2"; shift 2 ;;
    --release-dir) (($# >= 2)) || { echo "ERROR: --release-dir requires a directory"; exit 2; }; RELEASE_DIR="$2"; shift 2 ;;
    --yes) ASSUME_YES=1; shift ;;
    --allow-erase) ALLOW_ERASE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

[ -n "$TARGET" ] || { echo "ERROR: --target is required"; usage >&2; exit 2; }
if (( ASSUME_YES == 1 && ALLOW_ERASE != 1 )); then
  echo "ERROR: --yes requires the separate --allow-erase acknowledgement."
  exit 2
fi
[[ -d "$RELEASE_DIR" ]] || { echo "ERROR: release directory missing: $RELEASE_DIR"; exit 1; }
RELEASE_DIR="$(cd "$RELEASE_DIR" && pwd)"
RELEASE_NAME="$(basename "$RELEASE_DIR")"
RELEASE_PARENT="$(dirname "$RELEASE_DIR")"
SUM_FILE="$RELEASE_PARENT/$RELEASE_NAME.sha256"

for tool in lsblk findmnt sfdisk partprobe mkfs.ext4 mount umount cp grub-install sync blockdev stat sha256sum file grep awk find; do
  command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: required tool missing: $tool"; exit 1; }
done

[[ $EUID -eq 0 ]] || { echo "ERROR: run with sudo/root; no disk was changed."; exit 1; }
[[ -b "$TARGET" ]] || { echo "ERROR: target is not a block device: $TARGET"; exit 1; }
[[ "$(lsblk -ndo TYPE "$TARGET" | head -n 1)" == "disk" ]] || {
  echo "ERROR: target must be a whole disk, not a partition: $TARGET"
  exit 1
}

KERNEL_IMAGE="$RELEASE_DIR/boot/bzImage"
INITRAMFS_IMAGE="$RELEASE_DIR/boot/initramfs.cpio"
ROOTFS_IMAGE="$RELEASE_DIR/aira-rootfs.img"
for file in "$KERNEL_IMAGE" "$INITRAMFS_IMAGE" "$ROOTFS_IMAGE"; do
  [[ -s "$file" ]] || { echo "ERROR: required release artifact missing/empty: $file"; exit 1; }
done

# Verify the complete release manifest before touching the target disk.
[[ -s "$SUM_FILE" ]] || { echo "ERROR: release checksum manifest missing: $SUM_FILE"; exit 1; }
echo "[preflight] Verifying release checksums: $SUM_FILE"
(cd "$RELEASE_PARENT" && sha256sum -c "$(basename "$SUM_FILE")") || {
  echo "ERROR: release checksum verification failed; disk was not changed."
  exit 1
}
file "$ROOTFS_IMAGE" | grep -Eqi 'ext[234] filesystem data' || {
  echo "ERROR: release rootfs is not recognized as an ext filesystem image."
  exit 1
}

if lsblk -nrpo NAME,MOUNTPOINT "$TARGET" | awk 'NF > 1 && $2 != "" { found=1 } END { exit !found }'; then
  echo "ERROR: target or one of its partitions is mounted; refusing to erase it."
  exit 1
fi
if findmnt -rn -S "$TARGET" >/dev/null 2>&1; then
  echo "ERROR: target is mounted; refusing to erase it."
  exit 1
fi
TARGET_BYTES="$(blockdev --getsize64 "$TARGET")"
ROOTFS_BYTES="$(stat -c %s "$ROOTFS_IMAGE")"
[[ "$TARGET_BYTES" =~ ^[0-9]+$ && "$ROOTFS_BYTES" =~ ^[0-9]+$ ]] || {
  echo "ERROR: could not determine target/rootfs size; disk was not changed."
  exit 1
}
MIN_TARGET_BYTES=$((ROOTFS_BYTES + 64 * 1024 * 1024))
if (( TARGET_BYTES < MIN_TARGET_BYTES )); then
  echo "ERROR: target disk is too small (${TARGET_BYTES} bytes); need at least ${MIN_TARGET_BYTES} bytes for the rootfs plus partition overhead."
  exit 1
fi
GRUB_MODULE_DIR="$(find /usr/lib/grub /usr/lib64/grub -maxdepth 2 -type d -name i386-pc -print -quit 2>/dev/null || true)"
[[ -n "$GRUB_MODULE_DIR" ]] || {
  echo "ERROR: BIOS GRUB modules (i386-pc) are missing; install the host GRUB PC modules before formatting."
  exit 1
}

# Validate the rootfs image itself before asking to erase a disk. A read-only
# mount with noload avoids journal replay or writes to the release image.
PREFLIGHT_MNT="$(mktemp -d /tmp/aira-rootfs-preflight.XXXXXX)" || {
  echo "ERROR: cannot create rootfs preflight mountpoint; target disk was not changed."
  exit 1
}
PREFLIGHT_MOUNTED=0
cleanup_preflight() {
  set +e
  if (( PREFLIGHT_MOUNTED != 0 )); then umount "$PREFLIGHT_MNT"; fi
  [[ -z "$PREFLIGHT_MNT" ]] || rmdir "$PREFLIGHT_MNT"
}
trap cleanup_preflight EXIT HUP INT TERM
if ! mount -o loop,ro,noload "$ROOTFS_IMAGE" "$PREFLIGHT_MNT"; then
  echo "ERROR: rootfs image cannot be mounted read-only; target disk was not changed."
  exit 1
fi
PREFLIGHT_MOUNTED=1
if [[ ! -d "$PREFLIGHT_MNT/etc/aira" ||
      ! -x "$PREFLIGHT_MNT/usr/bin/aira-session" ||
      ! -x "$PREFLIGHT_MNT/usr/bin/jwm" ||
      ! -x "$PREFLIGHT_MNT/usr/bin/xterm" ]]; then
  echo "ERROR: rootfs image is missing required desktop files; target disk was not changed."
  exit 1
fi
if ! umount "$PREFLIGHT_MNT"; then
  echo "ERROR: cannot unmount rootfs preflight image; target disk was not changed."
  exit 1
fi
PREFLIGHT_MOUNTED=0
rmdir "$PREFLIGHT_MNT"
PREFLIGHT_MNT=""
trap - EXIT HUP INT TERM
echo "[preflight] Rootfs mounted read-only; required desktop payload present."

echo "TARGET DISK: $TARGET"
lsblk -dn -o MODEL,SIZE,TYPE "$TARGET"
echo "Release: $RELEASE_DIR"
echo "This operation will erase the entire target disk and create one ext4 partition."
if (( ASSUME_YES == 0 )); then
  printf 'Type ERASE %s to continue: ' "$TARGET"
  IFS= read -r confirmation || exit 1
  [[ "$confirmation" == "ERASE $TARGET" ]] || { echo "Aborted; disk was not changed."; exit 1; }
fi

TMP="$(mktemp -d /tmp/aira-install.XXXXXX)"
TARGET_MNT="$TMP/target"
SOURCE_MNT="$TMP/rootfs-source"
mkdir -p "$TARGET_MNT" "$SOURCE_MNT"
cleanup() {
  set +e
  (( SOURCE_MOUNTED == 0 )) || umount "$SOURCE_MNT"
  (( TARGET_MOUNTED == 0 )) || umount "$TARGET_MNT"
  [[ -z "$TMP" ]] || rm -rf -- "$TMP"
}
trap cleanup EXIT HUP INT TERM

echo "[install] Writing a fresh DOS partition table to $TARGET"
sfdisk --wipe always --wipe-partitions always "$TARGET" <<'EOF'
label: dos
unit: sectors

, ,83,*
EOF
partprobe "$TARGET"
if command -v udevadm >/dev/null 2>&1; then udevadm settle; fi

case "$TARGET" in
  *[0-9]) PART="${TARGET}p1" ;;
  *) PART="${TARGET}1" ;;
esac
for _try in 1 2 3 4 5 6 7 8 9 10; do
  [[ -b "$PART" ]] && break
  sleep 1
done
[[ -b "$PART" ]] || { echo "ERROR: partition device did not appear: $PART"; exit 1; }

echo "[install] Formatting $PART"
mkfs.ext4 -F -L AIRA_ROOT "$PART"
mount "$PART" "$TARGET_MNT"
TARGET_MOUNTED=1
mount -o loop,ro "$ROOTFS_IMAGE" "$SOURCE_MNT"
SOURCE_MOUNTED=1

echo "[install] Copying verified release root filesystem"
cp -a "$SOURCE_MNT/." "$TARGET_MNT/"
mkdir -p "$TARGET_MNT/boot/grub"
cp -f "$KERNEL_IMAGE" "$TARGET_MNT/boot/bzImage"
cp -f "$INITRAMFS_IMAGE" "$TARGET_MNT/boot/initramfs.cpio"
cat > "$TARGET_MNT/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0

menuentry "AiraOS-Octave" {
    linux /boot/bzImage console=tty0 console=ttyS0 rdinit=/init loglevel=7
    initrd /boot/initramfs.cpio
}
menuentry "AiraOS-Octave (safe mode)" {
    linux /boot/bzImage console=tty0 console=ttyS0 rdinit=/init loglevel=7 aira_safe=1
    initrd /boot/initramfs.cpio
}
EOF
cat > "$TARGET_MNT/etc/aira-install.info" <<EOF
distribution=AiraOS-Octave
release_dir=$RELEASE_DIR
installed_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
target_partition=$PART
EOF

[[ -s "$TARGET_MNT/boot/bzImage" && -s "$TARGET_MNT/boot/initramfs.cpio" ]] || {
  echo "ERROR: installed boot payload validation failed."
  exit 1
}
echo "[install] Installing BIOS GRUB"
grub-install --target=i386-pc --boot-directory="$TARGET_MNT/boot" --recheck "$TARGET"

sync
umount "$SOURCE_MNT"
SOURCE_MOUNTED=0
umount "$TARGET_MNT"
TARGET_MOUNTED=0
echo "INSTALL PASS: AiraOS-Octave installed to $TARGET"
echo "Firmware mode: legacy BIOS/CSM (UEFI installation is not implemented by this script)."
echo "Verify the machine can boot from the target before relying on it."
