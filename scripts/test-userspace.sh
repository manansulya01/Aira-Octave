#!/usr/bin/env bash
# Static userspace checks (no boot): layout, scripts syntax, service defs, packages.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/userspace"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/userspace-$TS.log"
PASS=1
{
  echo "TS=$TS"
  echo "== required dirs =="
  for d in initramfs initramfs/bin initramfs/etc initramfs/sbin initramfs/var/log/airaos; do
    if [ -e "$d" ]; then echo "OK $d"; else echo "MISS $d"; fi
  done
  echo "== required files =="
  for f in initramfs/init sbin/aira-init usr/bin/aira usr/bin/airapkg etc/os-release etc/hostname; do
    # check both initramfs/ and rootfs/ staging mirrors
    if [ -e "initramfs/$f" ] || [ -e "rootfs/$f" ] || [ -e "$f" ]; then echo "OK $f"; else echo "MISS $f"; fi
  done
  echo "== shell syntax =="
  for s in initramfs/init; do
    [ -f "$s" ] || continue
    if sh -n "$s" 2>&1; then echo "SYNTAX OK $s"; else echo "SYNTAX FAIL $s"; fi
  done
  for s in scripts/*.sh initramfs/sbin/* initramfs/usr/bin/*; do
    [ -f "$s" ] || continue
    if bash -n "$s" 2>&1; then echo "SYNTAX OK $s"; else echo "SYNTAX FAIL $s"; fi
  done
  echo "== busybox applets =="
  ls initramfs/bin 2>/dev/null || echo "(no initramfs/bin)"
} | tee "$LOG"

# Fail if core files missing
for f in initramfs/init scripts/boot-qemu.sh scripts/test-kernel.sh; do
  [ -f "$f" ] || { echo "FAIL missing $f"; PASS=0; }
done
# Fail on syntax errors
if grep -q "SYNTAX FAIL" "$LOG"; then PASS=0; fi
if grep -q "^MISS initramfs/init" "$LOG"; then PASS=0; fi

if [ "$PASS" = "1" ]; then echo "USERSPACE STATIC TEST PASS"; exit 0; else echo "USERSPACE STATIC TEST FAIL (see $LOG)"; exit 1; fi
