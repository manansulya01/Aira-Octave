#!/usr/bin/env bash
# Complete release pipeline test: build release -> verify checksums -> boot ISO.
# Usage: test-release.sh [VER]  (default 1.5.0)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
VER="${1:-1.5.0}"
echo "=== release pipeline for $VER ==="
bash "$ROOT/scripts/build-release.sh" "$VER" || { echo "RELEASE BUILD FAIL"; exit 1; }
echo "=== verifying checksums ==="
(cd "$ROOT/release" && sha256sum -c "aira-octave-$VER.sha256") || { echo "CHECKSUM FAIL"; exit 1; }
echo "=== booting ISO ==="
bash "$ROOT/scripts/test-iso.sh" "$VER" || { echo "ISO BOOT FAIL"; exit 1; }
echo "RELEASE PIPELINE PASS ($VER)"
