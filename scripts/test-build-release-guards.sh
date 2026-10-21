#!/usr/bin/env bash
# Unit-test release failure handling with mocked ISO/tar generators.
# This validates release orchestration/checksums, not a bootable ISO.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
TMP="$(mktemp -d)" || exit 1
trap 'rm -rf "$TMP"' EXIT
SANDBOX="$TMP/repo"
MOCKBIN="$TMP/mockbin"
mkdir -p "$SANDBOX/scripts" "$SANDBOX/linux-7.2.2/arch/x86/boot" "$SANDBOX/initramfs" "$SANDBOX/configs" "$SANDBOX/release" "$MOCKBIN" || exit 1
cp "$ROOT/scripts/build-release.sh" "$SANDBOX/scripts/build-release.sh" || exit 1
cp "$ROOT/scripts/boot-qemu.sh" "$SANDBOX/scripts/boot-qemu.sh" || exit 1
printf 'kernel-input\n' > "$SANDBOX/linux-7.2.2/arch/x86/boot/bzImage"
printf 'initramfs-input\n' > "$SANDBOX/initramfs.cpio"
printf 'rootfs-input\n' > "$SANDBOX/aira-rootfs.img"
printf 'kernel-config\n' > "$SANDBOX/configs/airaos-octave-x86_64.config"

cat > "$MOCKBIN/grub-mkrescue" <<'MOCK_GRUB'
#!/bin/sh
[ "${MOCK_GRUB_FAIL:-0}" = "0" ] || exit 42
[ "$1" = "-o" ] || exit 2
printf 'mock iso artifact\n' > "$2"
MOCK_GRUB
cat > "$MOCKBIN/tar" <<'MOCK_TAR'
#!/bin/sh
[ "${MOCK_TAR_FAIL:-0}" = "0" ] || exit 43
[ "$1" = "-czf" ] || exit 2
printf 'mock tar artifact\n' > "$2"
MOCK_TAR
chmod +x "$MOCKBIN/grub-mkrescue" "$MOCKBIN/tar"

REL="$SANDBOX/release/aira-octave-1.5.0"
ISO="$SANDBOX/release/aira-octave-1.5.0.iso"
TAR="$SANDBOX/release/aira-octave-1.5.0.tar.gz"
SUM="$SANDBOX/release/aira-octave-1.5.0.sha256"
mkdir -p "$REL"
printf 'previous release directory\n' > "$REL/KEEP-ME"
printf 'previous iso\n' > "$ISO"
printf 'previous tar\n' > "$TAR"
printf 'previous checksums\n' > "$SUM"

if PATH="$MOCKBIN:$PATH" bash "$SANDBOX/scripts/build-release.sh" '../invalid' > "$TMP/version.log" 2>&1; then
  echo "FAIL: unsafe version string was accepted"
  exit 1
fi
grep -q 'version must contain only' "$TMP/version.log" || {
  echo "FAIL: missing version validation diagnostic"
  exit 1
}
echo "PASS: invalid release version rejected"

if MOCK_GRUB_FAIL=1 PATH="$MOCKBIN:$PATH" bash "$SANDBOX/scripts/build-release.sh" 1.5.0 > "$TMP/fail.log" 2>&1; then
  echo "FAIL: simulated ISO generation failure was accepted"
  exit 1
fi
[ "$(cat "$ISO")" = "previous iso" ] || { echo "FAIL: existing ISO overwritten on failure"; exit 1; }
[ "$(cat "$TAR")" = "previous tar" ] || { echo "FAIL: existing tarball overwritten on failure"; exit 1; }
[ "$(cat "$SUM")" = "previous checksums" ] || { echo "FAIL: existing checksum manifest overwritten on failure"; exit 1; }
[ "$(cat "$REL/KEEP-ME")" = "previous release directory" ] || { echo "FAIL: existing versioned release directory changed on ISO failure"; exit 1; }
grep -q 'existing published release artifacts were not replaced' "$TMP/fail.log" || {
  echo "FAIL: missing failure-safe diagnostic"
  exit 1
}
echo "PASS: failed ISO build preserves previous published artifacts"

if MOCK_TAR_FAIL=1 PATH="$MOCKBIN:$PATH" bash "$SANDBOX/scripts/build-release.sh" 1.5.0 > "$TMP/tar-fail.log" 2>&1; then
  echo "FAIL: simulated tarball generation failure was accepted"
  exit 1
fi
[ "$(cat "$ISO")" = "previous iso" ] || { echo "FAIL: ISO changed after tarball failure"; exit 1; }
[ "$(cat "$TAR")" = "previous tar" ] || { echo "FAIL: tarball changed after its generation failure"; exit 1; }
[ "$(cat "$SUM")" = "previous checksums" ] || { echo "FAIL: checksum manifest changed after tarball failure"; exit 1; }
[ "$(cat "$REL/KEEP-ME")" = "previous release directory" ] || { echo "FAIL: versioned release directory changed after tarball failure"; exit 1; }
echo "PASS: failed tarball build preserves previous published artifacts"

if ! PATH="$MOCKBIN:$PATH" bash "$SANDBOX/scripts/build-release.sh" 1.5.0 > "$TMP/pass.log" 2>&1; then
  cat "$TMP/pass.log"
  echo "FAIL: mocked successful release build failed"
  exit 1
fi
grep -q 'RELEASE BUILD PASS' "$TMP/pass.log" || { echo "FAIL: success marker missing"; exit 1; }
[ "$(cat "$ISO")" = "mock iso artifact" ] || { echo "FAIL: ISO not published"; exit 1; }
[ "$(cat "$TAR")" = "mock tar artifact" ] || { echo "FAIL: tarball not published"; exit 1; }
[ ! -e "$REL/KEEP-ME" ] || { echo "FAIL: old versioned release directory was not replaced"; exit 1; }
[ "$(cat "$REL/boot/bzImage")" = "kernel-input" ] || { echo "FAIL: new versioned release directory content incorrect"; exit 1; }
[ "$(wc -l < "$SUM")" -eq 5 ] || { echo "FAIL: checksum manifest should contain five artifacts"; cat "$SUM"; exit 1; }
grep -q '^.*  aira-octave-1.5.0.iso$' "$SUM" || { echo "FAIL: ISO checksum filename incorrect"; exit 1; }
grep -q '^.*  aira-octave-1.5.0.tar.gz$' "$SUM" || { echo "FAIL: tar checksum filename incorrect"; exit 1; }
(cd "$SANDBOX/release" && sha256sum -c "aira-octave-1.5.0.sha256") || {
  echo "FAIL: published checksums do not verify"
  exit 1
}
if find "$SANDBOX/release" -maxdepth 1 -type d -name '.aira-release-*' | grep -q .; then
  echo "FAIL: temporary release workspace leaked"
  exit 1
fi
echo "PASS: successful release publishes artifacts and valid checksums"
echo "RELEASE GUARD TEST PASS (mocked ISO/tar generators; no bootable ISO built)"
