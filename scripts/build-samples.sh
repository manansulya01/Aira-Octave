#!/usr/bin/env bash
# Build sample applications + .apkg packages, stage into rootfs local repo.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/build"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/samples-build-$TS.log"
echo "LOG=$LOG" | tee "$LOG"
command -v gcc >/dev/null 2>&1 || { echo "ERROR: host gcc missing" | tee -a "$LOG"; exit 2; }
# hello-aira
make -C "$ROOT/samples/hello-aira" >>"$LOG" 2>&1 || { echo "ERROR: sample compile failed"; exit 1; }
mkdir -p "$ROOT/samples/hello-aira/pkg/usr/share/aira-samples"
cp -f "$ROOT/samples/hello-aira/hello-aira" "$ROOT/samples/hello-aira/pkg/usr/share/aira-samples/hello-aira"
chmod +x "$ROOT/samples/hello-aira/pkg/usr/share/aira-samples/hello-aira"
# package with initramfs airapkg? use host tar (same format: tar.gz + PKGINFO at root)
tar -czf "$ROOT/samples/hello-aira-1.0.apkg" -C "$ROOT/samples/hello-aira/pkg" . >>"$LOG" 2>&1 || exit 1
ls -lh "$ROOT/samples/hello-aira-1.0.apkg" | tee -a "$LOG"
# stage into rootfs local repo
mkdir -p "$ROOT/rootfs/var/lib/airapkg/repo"
cp -f "$ROOT/samples/hello-aira-1.0.apkg" "$ROOT/rootfs/var/lib/airapkg/repo/"
echo "SAMPLES BUILD PASS" | tee -a "$LOG"
