#!/usr/bin/env bash
# Aira doctor test (Wave C7): host-side contract tests. The host is NOT AiraOS,
# so most areas must report honest FAIL/WARN/UNKNOWN — that is the point of the
# test: a diagnostics tool that claims PASS on a non-Aira host is broken.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

D="$ROOT/initramfs/usr/bin/aira-doctor"
export AIRA_PKG_DB=/tmp/aira-doctor-nodb

echo "--- syntax ---"
sh -n "$D" 2>/dev/null && ok "aira-doctor syntax" || bad "aira-doctor syntax"
[ -x "$D" ] && ok "executable" || bad "executable"
sh "$D" --help >/dev/null 2>&1 && ok "--help" || bad "--help"
sh "$D" --bogus >/dev/null 2>&1 && bad "unknown option rejected" || ok "unknown option rejected"

echo "--- human output contract ---"
OUT="$(sh "$D" 2>/dev/null || true)"
printf '%s\n' "$OUT" | grep -q "summary: pass=" && ok "summary line present" || bad "summary line present"
# every check line: area check STATUS detail
BADLINE="$(printf '%s\n' "$OUT" | awk 'NF>=3 && $1!~/^---$/ && $1!~/^summary:/ && $3!~/^(PASS|FAIL|WARN|UNSUPPORTED|UNKNOWN)$/ {print}')"
[ -z "$BADLINE" ] && ok "every check line has a valid STATUS" || bad "every check line has a valid STATUS: $BADLINE"
for area in kernel userspace storage ipc services network security packages gui logs; do
  printf '%s\n' "$OUT" | grep -q "^$area " && ok "area present: $area" || bad "area present: $area"
done

echo "--- honesty: nothing PASSes that was not probed ---"
# On a non-Aira host these MUST NOT be PASS.
for chk in "ipc  bus" "services  manager" "packages  manager" "logs  dir"; do
  a="${chk%% *}"; c="${chk#* }"
  line="$(printf '%s\n' "$OUT" | awk -v a="$a" -v c="$c" '$1==a && $2==c {print $3}')"
  if [ "$line" = "PASS" ]; then bad "honest non-Aira: $a.$c must not be PASS"
  else ok "honest non-Aira: $a.$c = ${line:-absent}"; fi
done

echo "--- areas that must be probed positively ---"
printf '%s\n' "$OUT" | awk '$1=="kernel" && $2=="release" {print $3}' | grep -q PASS \
  && ok "kernel release probed PASS (real uname)" || bad "kernel release probed PASS"
printf '%s\n' "$OUT" | awk '$1=="kernel" && $2=="cpus" {print $3}' | grep -q PASS \
  && ok "cpu count probed PASS" || bad "cpu count probed PASS"
printf '%s\n' "$OUT" | awk '$1=="storage" && $2=="writable" {print $3}' | grep -q PASS \
  && ok "writability actually probed" || bad "writability actually probed"

echo "--- area filtering ---"
sh "$D" --areas kernel 2>/dev/null | awk 'NR>2 && NF>=3 {print $1}' | sort -u | grep -v '^$' | grep -v '^---$' | grep -v '^summary:' | grep -qv '^kernel$' \
  && bad "--areas limits output" || ok "--areas limits output"
sh "$D" --areas kernel 2>/dev/null | grep -q "^kernel " && ok "--areas keeps requested area" || bad "--areas keeps requested area"
sh "$D" --areas kernel 2>/dev/null | grep -q "^ipc " && bad "--areas excludes others" || ok "--areas excludes others"

echo "--- quiet mode ---"
Q="$(sh "$D" --quiet 2>/dev/null || true)"
printf '%s\n' "$Q" | grep -q " PASS " && bad "--quiet hides PASS" || ok "--quiet hides PASS"
printf '%s\n' "$Q" | grep -q " FAIL " && ok "--quiet keeps FAIL" || bad "--quiet keeps FAIL (host has failures)"

echo "--- json output ---"
J="$(sh "$D" --json 2>/dev/null || true)"
printf '%s\n' "$J" | head -1 | grep -q "^{" && ok "json opens with {" || bad "json opens with {"
printf '%s\n' "$J" | tail -2 | grep -q "summary" && ok "json has summary" || bad "json has summary"
printf '%s\n' "$J" | grep -q '"area":"kernel"' && ok "json has area field" || bad "json has area field"
printf '%s\n' "$J" | grep -q '"status":"PASS"' && ok "json has status field" || bad "json has status field"
printf '%s\n' "$J" | grep -q '"pass":[0-9]' && ok "json summary counts" || bad "json summary counts"
if command -v python3 >/dev/null 2>&1; then
  printf '%s\n' "$J" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d,dict)' 2>/dev/null \
    && ok "json parses as valid JSON" || bad "json parses as valid JSON"
else
  ok "json parse skipped (no python3)"
fi

echo "--- exit code reflects failures ---"
sh "$D" >/dev/null 2>&1 && bad "nonzero exit when checks fail" || ok "nonzero exit when checks fail"

echo "--- no fake-verdict patterns ---"
if grep -qE 'echo .*(always|assuming|pretend).*(PASS|OK)' "$D"; then bad "no hardcoded PASS"; else ok "no hardcoded PASS"; fi

echo
echo "DOCTOR TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]