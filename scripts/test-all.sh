#!/usr/bin/env bash
# AiraOS-Octave test runner. Preserve individual failures and report all results.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)" || exit 1
cd "$ROOT" || exit 1

OUTDIR="$ROOT/logs/final-completion/summary"
mkdir -p "$OUTDIR" || exit 1
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/test-all-$TS.log"
OVERALL=0

run() {
    local name="$1"
    shift

    echo "===== $name: $* =====" | tee -a "$LOG"
    "$@" 2>&1 | tee -a "$LOG"
    local rc=${PIPESTATUS[0]}

    if [ "$rc" -eq 0 ]; then
        echo "RESULT $name PASS" | tee -a "$LOG"
    else
        echo "RESULT $name FAIL rc=$rc" | tee -a "$LOG"
        OVERALL=1
    fi
}

# Core tests are mandatory.
for spec in \
    "kernel:scripts/test-kernel.sh" \
    "userspace-static:scripts/test-userspace.sh"
do
    name="${spec%%:*}"
    path="${spec#*:}"
    if [ -f "$path" ]; then
        run "$name" bash "$path"
    else
        echo "RESULT $name FAIL: missing $path" | tee -a "$LOG"
        OVERALL=1
    fi
done

# Run optional test scripts only when they exist.
for spec in \
    "shell:scripts/test-shell.sh" \
    "rootfs-atomic:scripts/test-build-rootfs-atomic.sh" \
    "features:scripts/test-features.sh" \
    "release-guards:scripts/test-build-release-guards.sh" \
    "files:scripts/test-files.sh" \
    "safe-mode:scripts/test-safe-mode.sh" \
    "settings:scripts/test-settings.sh" \
    "terms:scripts/test-terms.sh" \
    "sysstat:scripts/test-sysstat.sh" \
    "network:scripts/test-net.sh" \
    "user:scripts/test-user.sh" \
    "packages:scripts/test-pkg.sh" \
    "audio:scripts/test-audio.sh" \
    "update-safety:scripts/test-update-safety.sh" \
    "install-guard:scripts/test-install-guard.sh" \
    "guest-installer-guard:scripts/test-guest-installer-guard.sh" \
    "support-bundle:scripts/test-support-bundle.sh" \
    "doctor:scripts/test-doctor.sh" \
    "manifest:scripts/test-manifest.sh" \
    "services:scripts/test-services.sh" \
    "storage:scripts/test-storage.sh" \
    "legacy-network:scripts/test-network.sh" \
    "gui:scripts/test-gui.sh" \
    "demo:scripts/test-demo.sh"
do
    name="${spec%%:*}"
    path="${spec#*:}"
    if [ -f "$path" ]; then
        run "$name" bash "$path"
    else
        echo "SKIP $name (no $path)" | tee -a "$LOG"
    fi
done

if [ -f scripts/test-iso.sh ]; then
    iso="$(find release -maxdepth 1 -type f -name '*.iso' -printf '%T@ %p\n' 2>/dev/null |
        sort -nr | head -n 1 | cut -d' ' -f2-)"
    if [ -n "$iso" ]; then
        run iso bash scripts/test-iso.sh "$iso"
    else
        echo "SKIP iso (no release ISO found)" | tee -a "$LOG"
    fi
fi

if [ "$OVERALL" -eq 0 ]; then
    echo "TEST-ALL PASS" | tee -a "$LOG"
else
    echo "TEST-ALL FAIL" | tee -a "$LOG"
fi

echo "LOG=$LOG"
exit "$OVERALL"
