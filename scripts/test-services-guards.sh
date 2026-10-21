#!/usr/bin/env bash
# Service-name path traversal regressions. All state is redirected into a temp sandbox.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INIT="$ROOT/initramfs/sbin/aira-init"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BASE="$TMP/root"
SVC="$BASE/etc/aira/services"
EN="$BASE/etc/aira/enabled"
RUN="$BASE/run/aira-services"
LOG="$BASE/var/log/airaos"
mkdir -p "$SVC" "$EN" "$RUN" "$LOG"
printf 'must survive\n' > "$TMP/outside-sentinel"

run_init() {
  AIRA_SVC_DIR="$SVC" AIRA_EN_DIR="$EN" AIRA_RUN_DIR="$RUN" AIRA_LOG_DIR="$LOG" \
    sh "$INIT" "$@"
}

# Four parent components escape the enabled/services directories into $TMP.
for operation in disable enable start status; do
  if run_init "$operation" ../../../../outside-sentinel >"$TMP/$operation.out" 2>&1; then
    echo "FAIL: $operation accepted a traversal service name"
    exit 1
  fi
  grep -q 'bad service name' "$TMP/$operation.out" || {
    echo "FAIL: $operation did not reject traversal explicitly"
    cat "$TMP/$operation.out"
    exit 1
  }
  [ "$(cat "$TMP/outside-sentinel")" = "must survive" ] || {
    echo "FAIL: $operation modified a file outside the service directories"
    exit 1
  }
done
echo "PASS: service operations reject path traversal"

cat > "$SVC/probe.conf" <<EOF
DESC="sandbox service guard test"
CMD="printf success > '$TMP/ran'"
TYPE="oneshot"
DEPS=""
USER="root"
RESPAWN="no"
UMASK="022"
EOF
run_init start probe >"$TMP/probe.log" 2>&1
[ "$(cat "$TMP/ran")" = "success" ] || { echo "FAIL: valid service did not run"; exit 1; }
run_init enable probe >/dev/null
[ -e "$EN/probe" ] || { echo "FAIL: valid service did not enable"; exit 1; }
run_init disable probe >/dev/null
[ ! -e "$EN/probe" ] || { echo "FAIL: valid service did not disable"; exit 1; }
echo "PASS: valid service names retain expected behavior"
echo "SERVICE GUARD TEST PASS (sandbox only; no host service state touched)"
