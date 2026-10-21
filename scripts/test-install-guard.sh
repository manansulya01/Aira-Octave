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
echo "INSTALL GUARD TEST PASS (no block devices touched)"
