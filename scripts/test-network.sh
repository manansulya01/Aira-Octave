#!/usr/bin/env bash
# Network test: loopback must work; eth0 presence depends on QEMU NIC.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/network"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/network-$TS.log"
bash "$ROOT/scripts/boot-qemu.sh" --timeout 220 --log "$LOG" --net user --append "aira_autotest=1"
PASS=1
grep -q "GUEST-TEST OK: ping loopback" "$LOG" || { echo "MISS loopback ping"; PASS=0; }
grep -q "GUEST-TEST OK: ip link lo" "$LOG" || { echo "MISS lo"; PASS=0; }
grep -q "GUEST AUTOTEST PASS" "$LOG" || { echo "MISS guest pass"; PASS=0; }
if grep -qi "Kernel panic" "$LOG"; then PASS=0; fi
cp -f "$LOG" "$OUTDIR/last.log"
[ "$PASS" = "1" ] && { echo "NETWORK TEST PASS"; exit 0; } || { echo "NETWORK TEST FAIL (see $LOG)"; exit 1; }
