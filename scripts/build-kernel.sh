#!/usr/bin/env bash
# Build AiraOS-Octave kernel from canonical config. Fail loudly, log everything.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/build"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/kernel-build-$TS.log"
CANON="$ROOT/configs/airaos-octave-x86_64.config"

echo "LOG=$LOG"
{
  echo "TS=$TS"
  echo "CMD: cp configs/airaos-octave-x86_64.config linux-7.2.2/.config && make -C linux-7.2.2 olddefconfig && make -C linux-7.2.2 -j$(nproc) bzImage"
  git rev-parse HEAD
  gcc --version | head -n 1
  ld --version | head -n 1
  sha256sum "$CANON"
  wc -l "$CANON"
} | tee "$LOG"

if [ ! -f "$CANON" ]; then echo "ERROR: canonical config missing" | tee -a "$LOG"; exit 2; fi
cp "$CANON" linux-7.2.2/.config || { echo "ERROR: cp config failed" | tee -a "$LOG"; exit 1; }

# Validate config without full rebuild first
make -C linux-7.2.2 olddefconfig >>"$LOG" 2>&1 || { echo "ERROR: olddefconfig failed, see $LOG"; exit 1; }

# Incremental bzImage (fast if already built). Use timeout 90min max.
echo "Building bzImage (may take a while on first build)..." | tee -a "$LOG"
set +e
timeout 5400 make -C linux-7.2.2 -j"$(nproc)" bzImage >>"$LOG" 2>&1
RC=$?
set -u
echo "MAKE_EXIT=$RC" | tee -a "$LOG"
if [ $RC -ne 0 ]; then echo "ERROR: kernel build failed, see $LOG"; exit 1; fi

file linux-7.2.2/arch/x86/boot/bzImage | tee -a "$LOG"
ls -lh linux-7.2.2/arch/x86/boot/bzImage linux-7.2.2/vmlinux | tee -a "$LOG"
sha256sum linux-7.2.2/arch/x86/boot/bzImage linux-7.2.2/vmlinux | tee -a "$LOG"

if ! file linux-7.2.2/arch/x86/boot/bzImage | grep -q "Linux kernel x86 boot executable"; then
  echo "ERROR: bzImage type check failed"; exit 1
fi
if ! file linux-7.2.2/arch/x86/boot/bzImage | grep -q "version 7.2.2"; then
  echo "ERROR: version check failed"; exit 1
fi
echo "KERNEL BUILD PASS"
