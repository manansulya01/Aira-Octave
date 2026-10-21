#!/usr/bin/env bash
# SHA-256 checksums are not cryptographic signatures. Signing commands must
# fail closed until the OS has a real signature format and trusted-key policy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/src"
printf 'NAME="unsigned-test"\nVERSION="1.0"\nDESC="signing guard"\nDEPS=""\n' > "$TMP/src/PKGINFO"
printf 'payload\n' > "$TMP/src/payload.txt"
printf 'not-a-real-private-key\n' > "$TMP/private.pem"
printf 'not-a-real-public-key\n' > "$TMP/public.pem"
PKG="$TMP/unsigned.apkg"

sh "$ROOT/initramfs/usr/bin/airapkg" build "$TMP/src" "$PKG" > "$TMP/build.log"
[ -s "$PKG" ] || { echo "FAIL: unsigned package build missing output"; exit 1; }

printf 'sentinel-checksum-sidecar\n' > "$PKG.sha256"
if sh "$ROOT/initramfs/usr/bin/airapkg" sign "$PKG" "$TMP/private.pem" > "$TMP/sign.log" 2>&1; then
  echo "FAIL: fake signing command returned success"
  exit 1
fi
[ "$(cat "$PKG.sha256")" = "sentinel-checksum-sidecar" ] || {
  echo "FAIL: sign command overwrote checksum sidecar"
  exit 1
}

sha256sum "$PKG" | awk '{print $1}' > "$PKG.sha256"
if sh "$ROOT/initramfs/usr/bin/airapkg" verify-sig "$PKG" "$TMP/public.pem" > "$TMP/verify.log" 2>&1; then
  echo "FAIL: checksum was accepted as a cryptographic signature"
  exit 1
fi
if sh "$ROOT/initramfs/usr/bin/airapkg" build "$TMP/src" "$TMP/signed.apkg" --sign "$TMP/private.pem" > "$TMP/build-sign.log" 2>&1; then
  echo "FAIL: build --sign claimed success without cryptographic signing"
  exit 1
fi
[ ! -e "$TMP/signed.apkg" ] && [ ! -e "$TMP/signed.apkg.sha256" ] || {
  echo "FAIL: build --sign left misleading artifacts"
  exit 1
}
if grep -Eqi 'Package signed|Signature verification not fully implemented|^Signed ' "$TMP/sign.log" "$TMP/verify.log" "$TMP/build-sign.log"; then
  echo "FAIL: signing command emitted a fake success claim"
  exit 1
fi
echo "PACKAGE SIGNING SAFETY PASS"
