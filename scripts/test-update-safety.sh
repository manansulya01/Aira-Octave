#!/usr/bin/env bash
# Update client must fail closed: no fake metadata/packages or false success.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/state"
printf 'NAME="AiraOS-Octave"\nVERSION="1.5.0"\n' > "$TMP/os-release"
printf 'keep-me\n' > "$TMP/state/previous.version"
printf 'empty-legacy-package\n' > "$TMP/state/airaos-9.9.9.apkg"
run_update() {
  AIRA_UPDATE_DIR="$TMP/state" AIRA_OS_RELEASE="$TMP/os-release" sh "$ROOT/initramfs/sbin/aira-update" "$@"
}
run_update status > "$TMP/status.log"
grep -q 'Current version: 1.5.0' "$TMP/status.log"
grep -q 'Remote update feed: disabled' "$TMP/status.log"
for cmd in check download install rollback; do
  if run_update "$cmd" > "$TMP/$cmd.log" 2>&1; then
    echo "FAIL: aira-update $cmd claimed success without a trusted update backend"
    exit 1
  fi
  grep -q 'no update data was changed' "$TMP/$cmd.log" || {
    echo "FAIL: aira-update $cmd omitted fail-closed diagnostic"
    exit 1
  }
done
[ "$(cat "$TMP/state/previous.version")" = "keep-me" ] || {
  echo "FAIL: legacy rollback marker was modified"
  exit 1
}
[ "$(cat "$TMP/state/airaos-9.9.9.apkg")" = "empty-legacy-package" ] || {
  echo "FAIL: unverified package candidate was modified"
  exit 1
}
[ "$(cat "$TMP/os-release")" = "$(printf 'NAME="AiraOS-Octave"\nVERSION="1.5.0"')" ] || {
  echo "FAIL: os-release was modified"
  exit 1
}
echo "UPDATE SAFETY TEST PASS (unconfigured remote updates fail closed)"
