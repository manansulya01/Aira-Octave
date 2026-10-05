#!/bin/sh
# Release manifest + checksums (Wave V groundwork).
# Records the exact artifacts that were built, their hashes, the git commit
# they came from, and the toolchain used. Never invents an artifact: missing
# files are reported as MISSING, not skipped silently.
set -u
ROOT="${AIRA_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
OUT="${1:-$ROOT/release/MANIFEST.txt}"
cd "$ROOT" || exit 1
mkdir -p "$(dirname "$OUT")"

emit() { # emit <label> <path>
  _l="$1"; _p="$2"
  if [ -f "$_p" ]; then
    printf '%-22s %12s  %s  %s\n' "$_l" "$(stat -c %s "$_p" 2>/dev/null || echo '?')" \
      "$(sha256sum "$_p" 2>/dev/null | cut -c1-64)" "${_p#$ROOT/}"
  else
    printf '%-22s %12s  %-64s  %s\n' "$_l" "MISSING" "-" "${_p#$ROOT/}"
  fi
}

{
  echo "AiraOS-Octave release manifest"
  echo "generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo unknown)"
  echo "git-commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "git-describe: $(git describe --tags --always 2>/dev/null || echo unknown)"
  echo "kernel-version: $(uname -r 2>/dev/null || echo unknown)"
  echo "builder: $(uname -srm 2>/dev/null || echo unknown)"
  echo
  printf '%-22s %12s  %-64s  %s\n' ARTIFACT BYTES SHA256 PATH
  emit kernel linux-7.2.2/arch/x86/boot/bzImage
  emit kernel-config configs/airaos-octave-x86_64.config
  emit initramfs initramfs.cpio
  emit rootfs-image aira-rootfs.img
  emit source-init initramfs/init
  emit canonical-ipc-lib usr/lib/aira-ipc.sh
  echo
  echo "component: files handler"
  emit files-handler initramfs/etc/aira/ipc/handlers/files
  emit files-cli initramfs/usr/bin/aira-files
  echo
  echo "component: settings"
  emit settings-schema initramfs/etc/aira/settings-schema
  emit settings-handler initramfs/etc/aira/ipc/handlers/settings
  emit settings-cli initramfs/usr/bin/aira-cfg
  echo
  echo "component: terminal sessions"
  emit terms-handler initramfs/etc/aira/ipc/handlers/terms
  emit terms-cli initramfs/usr/bin/aira-term
  echo
  echo "component: monitoring"
  emit sysstat-handler initramfs/etc/aira/ipc/handlers/sysstat
  emit sysstat-cli initramfs/usr/bin/aira-sysstat
  echo
  echo "component: network"
  emit network-handler initramfs/etc/aira/ipc/handlers/network
  emit network-cli initramfs/usr/bin/aira-net
  echo
  echo "component: packages + diagnostics"
  emit airapkg initramfs/usr/bin/airapkg
  emit aira-doctor initramfs/usr/bin/aira-doctor
  emit doctor-probes initramfs/etc/aira/doctor-probes
  echo
  echo "component: security data"
  emit mdev-conf initramfs/etc/mdev.conf
  emit shadow initramfs/etc/shadow
  echo
  echo "component: test suites"
  for t in test-shell test-features test-userspace test-files test-settings \
           test-terms test-sysstat test-net test-pkg test-doctor; do
    emit "$t" "scripts/$t.sh"
  done
  echo
  echo "NOTE: this manifest records what exists; it does not certify that"
  echo "      every component is verified. See docs/architecture/ for status."
} > "$OUT" 2>&1

echo "manifest written: $OUT"
grep -c MISSING "$OUT" 2>/dev/null | sed 's/^/missing artifacts: /'
exit 0