#!/usr/bin/env bash
# Reproducible initramfs build from initramfs/ source. Verifies contents.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/build"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/initramfs-build-$TS.log"
SRC="$ROOT/initramfs"
OUT="$ROOT/initramfs.cpio"

echo "LOG=$LOG"
{
  echo "TS=$TS"
  git rev-parse HEAD
  ls -R "$SRC"
} | tee "$LOG"

if [ ! -x "$SRC/init" ]; then echo "ERROR: $SRC/init missing/executable" | tee -a "$LOG"; exit 1; fi
if [ ! -f "$SRC/bin/busybox" ]; then echo "ERROR: $SRC/bin/busybox missing" | tee -a "$LOG"; exit 1; fi

# C0: canonical IPC client lib lives at usr/lib/aira-ipc.sh; sync into
# initramfs source so /usr/lib/aira-ipc.sh exists in-guest (gui apps source it).
if [ -f "$ROOT/usr/lib/aira-ipc.sh" ]; then
  mkdir -p "$SRC/usr/lib"
  cp -f "$ROOT/usr/lib/aira-ipc.sh" "$SRC/usr/lib/aira-ipc.sh"
  echo "SYNC usr/lib/aira-ipc.sh -> initramfs/usr/lib/aira-ipc.sh" | tee -a "$LOG"
else
  echo "ERROR: $ROOT/usr/lib/aira-ipc.sh missing (C0 shared API)" | tee -a "$LOG"; exit 1
fi
if [ ! -f "$SRC/usr/lib/aira-ipc.sh" ]; then echo "ERROR: usr/lib/aira-ipc.sh missing in initramfs source" | tee -a "$LOG"; exit 1; fi

# Executable bits matter inside the image: /init dispatches guest scripts and
# the IPC dispatcher execs handlers, so a 0644 file is silently unusable.
# The working tree cannot be trusted here (core.fileMode=false), so enforce
# the bits explicitly on every entry point before packing.
for x in \
  "$SRC/init" \
  "$SRC/sbin/aira-ipc-handle" "$SRC/sbin/aira-ipcd" "$SRC/sbin/aira-init" \
  "$SRC/sbin/guest-autotest.sh" "$SRC/sbin/guest-demo.sh" \
  "$SRC/sbin/guest-fileops.sh" "$SRC/sbin/guest-guidemo.sh" \
  "$SRC/sbin/guest-guivisible.sh" "$SRC/sbin/guest-inputtest.sh" \
  "$SRC/sbin/guest-monitest.sh" "$SRC/sbin/guest-settingstest.sh" \
  "$SRC/sbin/guest-termtest.sh" "$SRC/sbin/guest-nettest.sh" \
  "$SRC/sbin/guest-netpersist.sh" "$SRC/sbin/guest-devperm.sh" \
  "$SRC/sbin/guest-doctest.sh" \
  "$SRC/etc/aira/doctor-probes" \
  "$SRC/etc/aira/settings-schema" \
  "$SRC/usr/bin/aira" "$SRC/usr/bin/aira-ipc" "$SRC/usr/bin/aira-files" \
  "$SRC/usr/bin/aira-cfg" "$SRC/usr/bin/aira-term" "$SRC/usr/bin/aira-sysstat" \
      "$SRC/usr/bin/aira-net" "$SRC/usr/bin/aira-net-setup" \
  "$SRC/usr/bin/aira-doctor" \
  "$SRC/usr/bin/aira-info" "$SRC/usr/bin/aira-log" "$SRC/usr/bin/aira-user" \
  "$SRC/usr/bin/aira-power" "$SRC/usr/bin/aira-audio" "$SRC/usr/bin/aird-info" \
  "$SRC/usr/bin/aira-sdk" "$SRC/usr/bin/aira-demo" \
  "$SRC/usr/bin/aira-device-setup" "$SRC/usr/bin/airapkg" \
  "$SRC/etc/aira/ipc/handlers/bus" "$SRC/etc/aira/ipc/handlers/device" \
  "$SRC/etc/aira/ipc/handlers/network" "$SRC/etc/aira/ipc/handlers/services" \
  "$SRC/etc/aira/ipc/handlers/storage" "$SRC/etc/aira/ipc/handlers/system" \
  "$SRC/etc/aira/ipc/handlers/user" "$SRC/etc/aira/ipc/handlers/files" \
  "$SRC/etc/aira/ipc/handlers/settings" "$SRC/etc/aira/ipc/handlers/terms" \
  "$SRC/etc/aira/ipc/handlers/sysstat"
do
  [ -f "$x" ] && chmod +x "$x" 2>/dev/null
done
# Verify the critical dispatch targets really are executable in the SOURCE tree.
for need in init sbin/aira-ipc-handle sbin/guest-nettest.sh \
            sbin/guest-netpersist.sh sbin/guest-devperm.sh \
            usr/bin/aira-net usr/bin/aira-doctor \
            etc/aira/doctor-probes etc/aira/settings-schema \
            etc/aira/ipc/handlers/network; do
  if [ ! -x "$SRC/$need" ]; then
    echo "ERROR: $need is not executable in initramfs source" | tee -a "$LOG"; exit 1
  fi
done
echo "MODE CHECK: exec bits enforced on initramfs entry points" | tee -a "$LOG"

# Build to temp, verify, then replace (keep .bak)
TMP="$OUTDIR/initramfs-$TS.cpio"
(
  cd "$SRC" || exit 1
  find . -print0 | cpio --format=newc --create --null > "$TMP"
) >>"$LOG" 2>&1 || { echo "ERROR: cpio failed"; exit 1; }

echo "--- new image contents (first 50) ---" | tee -a "$LOG"
cpio -t < "$TMP" 2>/dev/null | head -n 50 | tee -a "$LOG"
for need in init bin/busybox bin/sh; do
  if cpio -t < "$TMP" 2>/dev/null | grep -qx "$need"; then
    echo "CHECK $need OK" | tee -a "$LOG"
  else
    # allow ./ prefix variant
    if cpio -t < "$TMP" 2>/dev/null | grep -qx "./$need"; then
      echo "CHECK $need OK (./ prefix)" | tee -a "$LOG"
    else
      echo "ERROR: $need missing in new initramfs" | tee -a "$LOG"; exit 1
    fi
  fi
done

ls -lh "$TMP" | tee -a "$LOG"
sha256sum "$TMP" | tee -a "$LOG"
if [ -f "$OUT" ]; then cp -f "$OUT" "$OUT.bak-$TS"; echo "backup: $OUT.bak-$TS" | tee -a "$LOG"; fi
cp -f "$TMP" "$OUT"
echo "INITRAMFS BUILD PASS: $OUT"
