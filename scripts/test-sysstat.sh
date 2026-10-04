#!/usr/bin/env bash
# Aira monitor test (Wave C4): host-only checks for the sysstat snapshot
# service (direct exec), aira-sysstat CLI, sysmon migration, and overhead.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

H="$ROOT/initramfs/etc/aira/ipc/handlers/sysstat"
export AIRA_SYSSTAT_HANDLER="$H"
export PATH="$ROOT/initramfs/usr/bin:$PATH"

echo "--- syntax ---"
for f in "$H" initramfs/usr/bin/aira-sysstat gui/aira-sysmon initramfs/sbin/guest-monitest.sh initramfs/init; do
  if sh -n "$f" 2>/dev/null; then ok "$f syntax"; else bad "$f syntax"; fi
done
if grep -q '^PRIV_METHODS=' "$H"; then bad "sysstat stays read-only"; else ok "sysstat stays read-only"; fi
if grep -q 'eval ' "$H"; then bad "no eval in handler"; else ok "no eval in handler"; fi

echo "--- caps/snapshot sections ---"
sh "$H" caps | grep -q "methods=caps,snapshot" && ok "caps" || bad "caps"
sh "$H" snapshot > /tmp/sysstat-test.out 2>&1 || bad "snapshot rc"
ck() { grep -q "$2" /tmp/sysstat-test.out 2>/dev/null && ok "$1" || bad "$1"; }
ck "cpu cpus" "^cpu.cpus="
ck "cpu busy pct" "^cpu.busy_pct="
ck "load" "^load.1="
ck "uptime" "^uptime.s="
ck "mem total" "^mem.total_kb="
ck "mem used pct" "^mem.used_pct="
ck "proc count" "^procs.count="
ck "top rows" "^top="
ck "storage root" "^storage=/|"
ck "net rows" "^net="
CAPS="$(sh "$H" caps)"
case "$CAPS" in *thermal=no*)
  grep -q "^thermal=" /tmp/sysstat-test.out 2>/dev/null && bad "phantom thermal" || ok "no phantom thermal" ;;
*) grep -q "^thermal=" /tmp/sysstat-test.out 2>/dev/null && ok "thermal present+reported" || bad "thermal missing despite caps" ;; esac
case "$CAPS" in *battery=no*)
  grep -q "^battery=" /tmp/sysstat-test.out 2>/dev/null && bad "phantom battery" || ok "no phantom battery" ;;
*) grep -q "^battery=" /tmp/sysstat-test.out 2>/dev/null && ok "battery present+reported" || bad "battery missing despite caps" ;; esac

echo "--- arg/method discipline ---"
sh "$H" snapshot extra >/dev/null 2>&1 && bad "snapshot args" || ok "snapshot args rejected"
sh "$H" bogus >/dev/null 2>&1 && bad "unknown method" || ok "unknown method rejected"

echo "--- overhead (measured, not guessed) ---"
T0=$(date +%s%N 2>/dev/null || echo 0)
i=0; while [ "$i" -lt 3 ]; do sh "$H" snapshot >/dev/null 2>&1 || bad "repeat $i"; i=$((i+1)); done
T1=$(date +%s%N 2>/dev/null || echo 0)
if [ "$T0" != "0" ] && [ "$T1" != "0" ]; then
  MS=$(( (T1-T0)/3000000 ))
  echo "  INFO: snapshot avg ${MS}ms over 3 runs (host)"
  [ "$MS" -lt 2000 ] && ok "snapshot fast (<2s avg)" || bad "snapshot fast (<2s avg)"
else
  ok "snapshot completes (no ns clock)"
fi
L0=$(date +%s%N 2>/dev/null || echo 0)
bash "$ROOT/gui/aira-sysmon" --once >/dev/null 2>&1 || true
L1=$(date +%s%N 2>/dev/null || echo 0)
if [ "$L0" != "0" ] && [ "$L1" != "0" ]; then
  echo "  INFO: sysmon --once (backend path) $(( (L1-L0)/1000000 ))ms incl. one snapshot call"
fi

echo "--- CLI (local fallback, no bus on host) ---"
sh "$ROOT/initramfs/usr/bin/aira-sysstat" caps | grep -q "snapshot" && ok "cli caps" || bad "cli caps"
sh "$ROOT/initramfs/usr/bin/aira-sysstat" snapshot | grep -q "procs.count" && ok "cli snapshot" || bad "cli snapshot"
sh "$ROOT/initramfs/usr/bin/aira-sysstat" watch notanum >/dev/null 2>&1 && bad "cli bad interval" || ok "cli bad interval rejected"
sh "$ROOT/initramfs/usr/bin/aira-sysstat" bogus >/dev/null 2>&1 && bad "cli unknown" || ok "cli unknown rejected"

echo "--- sysmon migration ---"
[ -x "$ROOT/gui/aira-sysmon" ] && ok "sysmon executable" || bad "sysmon executable"
bash "$ROOT/gui/aira-sysmon" --once 2>/dev/null | grep -q "cpu.busy_pct" && ok "sysmon uses snapshot backend" || bad "sysmon uses snapshot backend"
bash "$ROOT/gui/aira-sysmon" --once 2>/dev/null | grep -q "direct" && bad "backend unexpectedly skipped" || ok "backend preferred over fallback"
PATH="/usr/bin:/bin" bash "$ROOT/gui/aira-sysmon" --once 2>/dev/null | grep -q "direct" && ok "direct fallback survives" || bad "direct fallback survives"

echo
echo "SYSSTAT TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
