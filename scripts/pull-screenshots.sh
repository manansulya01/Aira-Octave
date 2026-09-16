#!/usr/bin/env bash
# Extract /screenshots from aira-rootfs.img into docs/research/0.2/screenshots/ via debugfs.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMG="$ROOT/aira-rootfs.img"
OUT="$ROOT/docs/research/0.2/screenshots"
mkdir -p "$OUT"
echo "listing /screenshots in image:"
debugfs -R "ls screenshots" "$IMG"
for f in $(debugfs -R "ls screenshots" "$IMG" 2>/dev/null | awk '{print $NF}' | grep -E 'xwd|ppm|png'); do
  echo "dumping $f"
  debugfs -R "dump screenshots/$f $OUT/$f" "$IMG"
done
ls -lh "$OUT"
