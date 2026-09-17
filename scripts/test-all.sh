#!/usr/bin/env bash
# Run full feasible automated suite. Continues on failure, reports summary.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/summary"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/test-all-$TS.log"
OVERALL=0
run() {
  local name="$1"; shift
  echo "===== $name: $* =====" | tee -a "$LOG"
  set +e
  "$@" 2>&1 | tee -a "$LOG"
  local rc=${PIPESTATUS[0]}
  set -u
  if [ $rc -eq 0 ]; then echo "RESULT $name PASS" | tee -a "$LOG";
  else echo "RESULT $name FAIL rc=$rc" | tee -a "$LOG"; OVERALL=1; fi
}
run kernel bash scripts/test-kernel.sh
run userspace-static bash scripts/test-userspace.sh
[ -x scripts/test-services.sh ] && run services bash scripts/test-services.sh || echo "SKIP services (no script yet)" | tee -a "$LOG"
[ -x scripts/test-storage.sh ] && run storage bash scripts/test-storage.sh || echo "SKIP storage (no script yet)" | tee -a "$LOG"
[ -x scripts/test-network.sh ] && run network bash scripts/test-network.sh || echo "SKIP network (no script yet)" | tee -a "$LOG"
[ -x scripts/test-gui.sh ] && run gui bash scripts/test-gui.sh || echo "SKIP gui (no script yet)" | tee -a "$LOG"
[ -x scripts/test-demo.sh ] && run demo bash scripts/test-demo.sh || echo "SKIP demo (no script yet)" | tee -a "$LOG"
[ -x scripts/test-iso.sh ] && run iso bash scripts/test-iso.sh 0.2.0 || echo "SKIP iso (no script yet)" | tee -a "$LOG"
if [ "$OVERALL" = "0" ]; then echo "TEST-ALL PASS" | tee -a "$LOG"; else echo "TEST-ALL FAIL (see $LOG)" | tee -a "$LOG"; fi
exit $OVERALL
