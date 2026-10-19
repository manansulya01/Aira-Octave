#!/usr/bin/env bash
# Boot a guest and verify the diagnostic support bundle end-to-end.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/support-bundle"
mkdir -p "$OUTDIR" || exit 1
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/support-bundle-$TS.log"

echo "SUPPORT_BUNDLE_TEST_LOG=$LOG"
bash "$ROOT/scripts/boot-qemu.sh" --timeout 60 --log "$LOG" --append "aira_supporttest=1"
if grep -q "GUEST SUPPORT BUNDLE TEST PASS" "$LOG"; then
  echo "SUPPORT BUNDLE TEST PASS"
  exit 0
fi
echo "SUPPORT BUNDLE TEST FAIL (see $LOG)"
grep -E "GUEST-SUPPORT-TEST (OK|FAIL)|GUEST SUPPORT BUNDLE TEST" "$LOG" || true
exit 1
