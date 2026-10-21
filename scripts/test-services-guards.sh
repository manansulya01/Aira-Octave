#!/usr/bin/env bash
# Service-name traversal and resource-limit regressions; all state is sandboxed.
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
printf 'private-log-marker\n' > "$TMP/outside-sentinel.log"

run_init() {
  AIRA_SVC_DIR="$SVC" AIRA_EN_DIR="$EN" AIRA_RUN_DIR="$RUN" AIRA_LOG_DIR="$LOG" \
    sh "$INIT" "$@"
}

# These names would escape the service, enabled, or log directories without
# validation. The outside sentinels prove that no file is removed or disclosed.
for operation in disable enable start stop status diag logs; do
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
    echo "FAIL: $operation modified a file outside service directories"
    exit 1
  }
  [ "$(cat "$TMP/outside-sentinel.log")" = "private-log-marker" ] || {
    echo "FAIL: $operation modified a log outside the service log directory"
    exit 1
  }
  if grep -q 'private-log-marker' "$TMP/$operation.out"; then
    echo "FAIL: $operation exposed a log outside the service log directory"
    exit 1
  fi
done
echo "PASS: service operations reject path traversal"

cat > "$SVC/probe.conf" <<'EOF'
DESC="sandbox service guard test"
CMD="printf success > '__RAN_PATH__'"
TYPE="oneshot"
DEPS=""
USER="root"
RESPAWN="no"
UMASK="022"
EOF
sed "s|__RAN_PATH__|$TMP/ran|g" "$SVC/probe.conf" > "$TMP/probe.conf"
mv "$TMP/probe.conf" "$SVC/probe.conf"
run_init start probe >"$TMP/probe.log" 2>&1 || { cat "$TMP/probe.log"; exit 1; }
[ "$(cat "$TMP/ran")" = "success" ] || { echo "FAIL: valid service did not run"; exit 1; }
run_init enable probe >/dev/null
[ -e "$EN/probe" ] || { echo "FAIL: valid service did not enable"; exit 1; }
run_init disable probe >/dev/null
[ ! -e "$EN/probe" ] || { echo "FAIL: valid service did not disable"; exit 1; }
echo "PASS: valid service names retain expected behavior"

cat > "$SVC/limited.conf" <<'EOF'
DESC="resource limit enforcement test"
CMD='printf "%s %s %s %s" "$(ulimit -t)" "$(ulimit -n)" "$(umask)" "$(ps -o ni= -p $$)" > "__LIMITS_PATH__"'
TYPE="oneshot"
DEPS=""
USER="root"
RESPAWN="no"
LIMIT_CPU="7"
LIMIT_NOFILE="33"
NICE="5"
UMASK="027"
EOF
sed "s|__LIMITS_PATH__|$TMP/limits|g" "$SVC/limited.conf" > "$TMP/limited.conf"
mv "$TMP/limited.conf" "$SVC/limited.conf"
run_init start limited >"$TMP/limited.log" 2>&1 || { cat "$TMP/limited.log"; exit 1; }
grep -Eq '^7 33 0027 +5$' "$TMP/limits" || {
  echo "FAIL: child process did not receive configured CPU/file/umask/nice limits"
  cat "$TMP/limits" 2>/dev/null || true
  cat "$TMP/limited.log"
  exit 1
}
echo "PASS: oneshot resource limits apply inside the child process"

cat > "$SVC/badlimit.conf" <<'EOF'
DESC="invalid resource limit must fail closed"
CMD="touch '__INVALID_RAN__'"
TYPE="oneshot"
DEPS=""
USER="root"
RESPAWN="no"
LIMIT_CPU="7; touch '__PWNED__'"
UMASK="022"
EOF
sed -e "s|__INVALID_RAN__|$TMP/invalid-ran|g" -e "s|__PWNED__|$TMP/pwned|g" "$SVC/badlimit.conf" > "$TMP/badlimit.conf"
mv "$TMP/badlimit.conf" "$SVC/badlimit.conf"
if run_init start badlimit >"$TMP/badlimit.log" 2>&1; then
  echo "FAIL: malformed resource limit was accepted"
  exit 1
fi
grep -q 'invalid resource-limit' "$TMP/badlimit.log" || {
  echo "FAIL: malformed resource limit lacked a diagnostic"
  cat "$TMP/badlimit.log"
  exit 1
}
[ ! -e "$TMP/invalid-ran" ] && [ ! -e "$TMP/pwned" ] || {
  echo "FAIL: invalid service configuration executed a command"
  exit 1
}
echo "PASS: malformed resource limits fail closed"
echo "SERVICE GUARD TEST PASS (sandbox only; no host service state touched)"
