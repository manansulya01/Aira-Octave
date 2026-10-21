#!/usr/bin/env bash
# Safe preflight tests only: never create, format, or mount a block device.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$ROOT/scripts/install-to-disk.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

bash "$INSTALLER" --help > "$TMP/help.txt"
grep -q 'requires --allow-erase' "$TMP/help.txt"
if bash "$INSTALLER" --target /dev/aira-test-disk --yes > "$TMP/unsafe.log" 2>&1; then
  echo "FAIL: unattended install accepted without explicit erase acknowledgement"
  exit 1
fi
grep -q 'requires the separate --allow-erase acknowledgement' "$TMP/unsafe.log" || {
  echo "FAIL: unsafe unattended install did not fail at acknowledgement preflight"
  cat "$TMP/unsafe.log"
  exit 1
}
if bash "$INSTALLER" > "$TMP/missing-target.log" 2>&1; then
  echo "FAIL: install accepted without a target"
  exit 1
fi
grep -q -- '--target is required' "$TMP/missing-target.log"

# The rootfs image must be mounted read-only and checked before confirmation
# or any destructive disk command can run.
PREFLIGHT_LINE="$(grep -n 'mount -o loop,ro,noload' "$INSTALLER" | cut -d: -f1)"
CONFIRM_LINE="$(grep -n 'Type ERASE' "$INSTALLER" | cut -d: -f1)"
SFDISK_LINE="$(grep -n 'sfdisk --wipe always' "$INSTALLER" | cut -d: -f1)"
MKFS_LINE="$(grep -n 'mkfs.ext4 -F' "$INSTALLER" | cut -d: -f1)"
[[ "$PREFLIGHT_LINE" =~ ^[0-9]+$ && "$CONFIRM_LINE" =~ ^[0-9]+$ && "$SFDISK_LINE" =~ ^[0-9]+$ && "$MKFS_LINE" =~ ^[0-9]+$ ]] || {
  echo "FAIL: installer rootfs preflight or destructive command markers missing"
  exit 1
}
(( PREFLIGHT_LINE < CONFIRM_LINE && PREFLIGHT_LINE < SFDISK_LINE && PREFLIGHT_LINE < MKFS_LINE )) || {
  echo "FAIL: rootfs preflight must precede confirmation and disk modification"
  exit 1
}
grep -q 'rootfs image cannot be mounted read-only' "$INSTALLER"
grep -q 'rootfs image is missing required desktop files' "$INSTALLER"
echo "INSTALL GUARD TEST PASS (rootfs preflight precedes disk erase; no block devices touched)"
