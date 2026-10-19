#!/usr/bin/env bash
# Verify aira_safe=1 skips persistence/services/optional startup and reaches a shell.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/safe-mode"
mkdir -p "$OUTDIR" || exit 1
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/safe-mode-$TS.log"

echo "SAFE_MODE_LOG=$LOG"
bash "$ROOT/scripts/boot-qemu.sh" --timeout 25 --log "$LOG" --append "aira_safe=1"

PASS=1
check() {
  label="$1"
  pattern="$2"
  if grep -Eq "$pattern" "$LOG"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (pattern: $pattern)"
    PASS=0
  fi
}
reject() {
  label="$1"
  pattern="$2"
  if grep -Eq "$pattern" "$LOG"; then
    echo "FAIL: $label (unexpected pattern: $pattern)"
    PASS=0
  else
    echo "PASS: $label"
  fi
}

check "safe mode marker" "AIRA SAFE MODE ACTIVE"
check "persistence skipped" "\[init\] safe mode: skipping persistent disk mount"
check "services skipped" "\[init\] safe mode: skipping service startup"
check "recovery shell ready" "\[init\] safe mode recovery shell ready"
check "shell launched" "\[init\] launching shell \(safe recovery shell\)"
reject "service manager not started" "\[init\] starting AiraOS services"
reject "desktop not auto-started" "auto-starting AiraOS desktop"
reject "guest autotest hook not run" "detected, running guest autotest"

if [ "$PASS" -eq 1 ]; then
  echo "SAFE MODE TEST PASS"
  exit 0
fi
echo "SAFE MODE TEST FAIL (see $LOG)"
exit 1
