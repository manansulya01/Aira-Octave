#!/usr/bin/env bash
# Aira release-artifact test (Wave V groundwork): verifies the manifest
# actually describes the current tree (no stale hashes, no missing files).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
M="release/MANIFEST.txt"

echo "--- generate ---"
if bash scripts/release-manifest.sh >/dev/null 2>&1; then ok "manifest generated"; else bad "manifest generated"; fi
[ -f "$M" ] && ok "manifest exists" || { bad "manifest exists"; echo "DOCTOR/MANIFEST TEST: PASS=$PASS FAIL=$((FAIL+1))"; exit 1; }

echo "--- header facts ---"
grep -q "git-commit: $(git rev-parse HEAD)" "$M" && ok "manifest records current HEAD" || bad "manifest records current HEAD"
grep -q "^generated: 20" "$M" && ok "manifest timestamped" || bad "manifest timestamped"
grep -q "ARTIFACT.*BYTES.*SHA256.*PATH" "$M" && ok "manifest has a header row" || bad "manifest has a header row"
grep -q "does not certify" "$M" && ok "manifest disclaims certification" || bad "manifest disclaims certification"

echo "--- no missing artifacts ---"
# `grep -c` exits 1 when the count is 0, which would append a second "0".
MISS="$(grep -c MISSING "$M" 2>/dev/null || true)"
[ -z "$MISS" ] && MISS=0
[ "$MISS" = "0" ] && ok "no missing artifacts" || { bad "missing artifacts: $MISS"; grep MISSING "$M" | head -5; }

echo "--- recorded hashes are current ---"
STALE=""
while read -r label bytes sha path; do
  case "$label" in ARTIFACT|-*) continue ;; esac
  [ -n "${path:-}" ] || continue
  [ -f "$path" ] || continue
  cur="$(sha256sum "$path" 2>/dev/null | cut -c1-64)"
  [ "$cur" = "$sha" ] || STALE="$STALE $label"
done < "$M"
[ -z "$STALE" ] && ok "all recorded hashes current" || bad "stale hashes:$STALE"

echo "--- required components present ---"
for c in files-handler files-cli settings-schema settings-handler settings-cli \
         terms-handler terms-cli sysstat-handler sysstat-cli \
         network-handler network-cli airapkg aira-doctor doctor-probes \
         mdev-conf canonical-ipc-lib source-init; do
  grep -q "^$c " "$M" || { bad "component recorded: $c"; continue; }
  ok "component recorded: $c"
done

echo "--- test suites are listed ---"
for t in test-shell test-net test-pkg test-doctor; do
  grep -q "^$t " "$M" && ok "suite recorded: $t" || bad "suite recorded: $t"
done

echo "--- key artifacts are non-trivial ---"
for a in initramfs.cpio aira-rootfs.img linux-7.2.2/arch/x86/boot/bzImage; do
  [ -f "$a" ] || continue
  sz=$(stat -c %s "$a" 2>/dev/null || echo 0)
  [ "${sz:-0}" -gt 1024 ] && ok "artifact non-trivial: $a (${sz}B)" || bad "artifact too small: $a (${sz}B)"
done

echo
echo "MANIFEST TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]