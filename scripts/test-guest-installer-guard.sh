#!/usr/bin/env bash
# The live-image installer must never pretend it can install or touch a disk.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

sh "$ROOT/initramfs/sbin/aira-install" --help > "$TMP/help.txt"
grep -q 'No disk will be partitioned or formatted' "$TMP/help.txt"
if sh "$ROOT/initramfs/sbin/aira-install" --target /dev/aira-test-disk --auto --allow-erase > "$TMP/install.log" 2>&1; then
  echo "FAIL: in-guest installer claimed success"
  exit 1
fi
grep -q 'installation refused; no disk was changed' "$TMP/install.log" || {
  echo "FAIL: in-guest installer did not fail closed"
  cat "$TMP/install.log"
  exit 1
}
echo "GUEST INSTALLER GUARD PASS (no disk operations attempted)"
