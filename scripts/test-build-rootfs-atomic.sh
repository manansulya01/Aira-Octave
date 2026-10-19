#!/usr/bin/env bash
# Unit-test rootfs publication behavior with mocked mkfs/file tools.
# This verifies failure safety and control flow; it does not build a real ext4 image.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
TMP="$(mktemp -d)" || exit 1
trap 'rm -rf "$TMP"' EXIT
SANDBOX="$TMP/repo"
MOCKBIN="$TMP/mockbin"
mkdir -p "$SANDBOX/scripts" "$SANDBOX/rootfs" "$SANDBOX/initramfs/etc" "$MOCKBIN" || exit 1
cp "$ROOT/scripts/build-rootfs.sh" "$SANDBOX/scripts/build-rootfs.sh" || exit 1
chmod +x "$SANDBOX/scripts/build-rootfs.sh"

cat > "$MOCKBIN/mkfs.ext4" <<'MOCK_MKFS'
#!/bin/sh
if [ "${MOCK_MKFS_FAIL:-0}" = "1" ]; then
  echo "simulated mkfs failure" >&2
  exit 42
fi
printf 'mock ext4 image\n' > "$5"
MOCK_MKFS
cat > "$MOCKBIN/file" <<'MOCK_FILE'
#!/bin/sh
echo "$1: Linux rev 1.0 ext4 filesystem data"
MOCK_FILE
chmod +x "$MOCKBIN/mkfs.ext4" "$MOCKBIN/file"

IMG="$SANDBOX/aira-rootfs.img"
printf 'known-good-image\n' > "$IMG"
if MOCK_MKFS_FAIL=1 PATH="$MOCKBIN:$PATH" bash "$SANDBOX/scripts/build-rootfs.sh" 256 > "$TMP/fail.log" 2>&1; then
  echo "FAIL: simulated mkfs error was accepted"
  exit 1
fi
if [ "$(cat "$IMG")" != "known-good-image" ]; then
  echo "FAIL: existing image changed after failed mkfs"
  exit 1
fi
grep -q "existing image was not changed" "$TMP/fail.log" || {
  echo "FAIL: missing failure-safe diagnostic"
  exit 1
}
echo "PASS: failed mkfs preserves existing image"

if PATH="$MOCKBIN:$PATH" bash "$SANDBOX/scripts/build-rootfs.sh" invalid > "$TMP/invalid.log" 2>&1; then
  echo "FAIL: invalid image size was accepted"
  exit 1
fi
if [ "$(cat "$IMG")" != "known-good-image" ]; then
  echo "FAIL: invalid size changed existing image"
  exit 1
fi
echo "PASS: invalid size preserves existing image"

if ! PATH="$MOCKBIN:$PATH" bash "$SANDBOX/scripts/build-rootfs.sh" 64 > "$TMP/pass.log" 2>&1; then
  cat "$TMP/pass.log"
  echo "FAIL: valid mocked build did not pass"
  exit 1
fi
grep -q "ROOTFS BUILD PASS" "$TMP/pass.log" || {
  echo "FAIL: success marker missing"
  exit 1
}
[ "$(cat "$IMG")" = "mock ext4 image" ] || {
  echo "FAIL: successful build did not publish replacement image"
  exit 1
}
if find "$SANDBOX" -maxdepth 1 -type d -name '.aira-rootfs-build.*' | grep -q .; then
  echo "FAIL: temporary build directory leaked"
  exit 1
fi
echo "PASS: successful build atomically publishes validated image"
echo "ROOTFS ATOMIC BUILD TEST PASS (mocked mkfs; no real ext4 image built)"
