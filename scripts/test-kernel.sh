#!/usr/bin/env bash
# AiraOS-Octave kernel boot test: builds nothing, boots existing bzImage+initramfs,
# checks machine-detectable markers, correct exit codes, timestamped logs.
# PASS = Linux version + Run /init + AiraOS userspace ready + no panic/oops
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

OUTDIR="$ROOT/logs/final-completion/baseline"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/qemu-baseline-$TS.log"
FP="$OUTDIR/fingerprint-$TS.txt"

{
  echo "TS=$TS"
  echo "GIT_HEAD=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "GIT_STATUS:"
  git status --short 2>/dev/null || echo "git-status-failed"
  echo "---"
  echo "UNAME_M=$(uname -m)"
  gcc --version 2>/dev/null | head -n 1
  ld --version 2>/dev/null | head -n 1
  qemu-system-x86_64 --version 2>/dev/null | head -n 1
  echo "---"
  ls -lh linux-7.2.2/arch/x86/boot/bzImage linux-7.2.2/vmlinux initramfs.cpio linux-7.2.2/.config 2>/dev/null || true
  sha256sum linux-7.2.2/arch/x86/boot/bzImage linux-7.2.2/vmlinux initramfs.cpio linux-7.2.2/.config 2>/dev/null || true
  file linux-7.2.2/arch/x86/boot/bzImage 2>/dev/null || true
  grep -E "CONFIG_KERNEL_GZIP|CONFIG_KERNEL_XZ|CONFIG_PREEMPT_DYNAMIC" linux-7.2.2/.config 2>/dev/null || true
} | tee "$FP"

echo "BOOT_LOG=$LOG"
bash "$ROOT/scripts/boot-qemu.sh" --timeout 30 --log "$LOG" --mem 512M
# boot-qemu.sh always exits 0 after capture; analyze log here
PASS=1
FAIL_REASON=""

if grep -q "Linux version" "$LOG" 2>/dev/null; then echo "MARKER: Linux version OK"; else echo "MARKER: Linux version MISSING"; PASS=0; FAIL_REASON="$FAIL_REASON linux-version;"; fi
if grep -q "Run /init as init process" "$LOG" 2>/dev/null; then echo "MARKER: Run /init OK"; else echo "MARKER: Run /init MISSING"; PASS=0; FAIL_REASON="$FAIL_REASON rdinit;"; fi
if grep -q "AiraOS userspace ready" "$LOG" 2>/dev/null; then echo "MARKER: AiraOS userspace ready OK"; else echo "MARKER: AiraOS userspace ready MISSING"; PASS=0; FAIL_REASON="$FAIL_REASON userspace;"; fi
if grep -qi "Kernel panic" "$LOG" 2>/dev/null; then echo "MARKER: Kernel panic DETECTED (fail)"; PASS=0; FAIL_REASON="$FAIL_REASON panic;"; else echo "MARKER: no panic OK"; fi
if grep -q "Oops" "$LOG" 2>/dev/null; then echo "MARKER: Oops DETECTED (fail)"; PASS=0; FAIL_REASON="$FAIL_REASON oops;"; else echo "MARKER: no oops OK"; fi

cp -f "$LOG" "$OUTDIR/last-boot.log"
echo "$TS PASS=$PASS $FAIL_REASON" >> "$OUTDIR/results.log"

if [ "$PASS" = "1" ]; then
  echo "BOOT TEST PASS"
  exit 0
else
  echo "BOOT TEST FAIL:$FAIL_REASON"
  exit 1
fi
