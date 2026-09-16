#!/usr/bin/env bash
# Create BusyBox applet symlinks needed by AiraOS-Octave. Idempotent.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/initramfs/bin"
mkdir -p "$BIN"
# Keep existing 24 + add system-required applets (all supported by bundled busybox 1.37.0)
APPLETS="awk basename bc chmod chown df du env expr find id ifconfig ip kill killall logger login logread losetup lsmod mdev mkdir mknod mktemp modinfo modprobe more nc netstat nslookup passwd pidof ping route sed seq sh sha256sum stat stty su sync syslogd klogd tar top touch tr traceroute true udhcpc umount uptime vi w watch wc wget which who whoami xargs yes zcat gzip gunzip tar df du fdisk blkid findfs hwclock syslogd getty setsid start-stop-daemon run-parts df free ps uname hostname cat ls echo sh"
# Note: duplicates harmless (ln -sf). blkid is not a busybox applet name (use findfs); keep safe.
count=0
for a in $APPLETS; do
  # skip non-applets gracefully
  if "$BIN/busybox" --list 2>/dev/null | grep -qx "$a"; then
    ln -sf busybox "$BIN/$a"
    count=$((count+1))
  else
    echo "SKIP (not in busybox): $a"
  fi
done
echo "busybox links ensured: $count applets (total $(ls "$BIN" | wc -l) entries in initramfs/bin)"
ls "$BIN"
