#!/usr/bin/env bash
# List DT_NEEDED sonames in rootfs staging that have no file in staging.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$ROOT/rootfs"
TMPNEEDED="$(mktemp)"
TMPHAVE="$(mktemp)"
trap 'rm -f "$TMPNEEDED" "$TMPHAVE"' EXIT
# all provided sonames (basenames of .so* files + SONAMEs)
find "$STAGE" -name '*.so*' -printf '%f\n' 2>/dev/null | sort -u > "$TMPHAVE"
# also map SONAME -> file via readelf for libs that have SONAME different from filename
> "$TMPNEEDED"
while IFS= read -r -d '' f; do
  if readelf -d "$f" 2>/dev/null | grep -q NEEDED; then
    readelf -d "$f" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' >> "$TMPNEEDED"
  fi
done < <(find "$STAGE/usr/bin" "$STAGE/usr/sbin" "$STAGE/bin" "$STAGE/sbin" -type f 2>/dev/null | tr '\n' '\0')
# also check libs themselves (transitive)
while IFS= read -r -d '' f; do
  readelf -d "$f" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' >> "$TMPNEEDED" || true
done < <(find "$STAGE" -name '*.so*' 2>/dev/null | tr '\n' '\0')
sort -u "$TMPNEEDED" -o "$TMPNEEDED"
echo "== NEEDED total: $(wc -l < "$TMPNEEDED") =="
echo "== MISSING from staging: =="
miss=0
while IFS= read -r lib; do
  # skip vdso/ld-linux (provided by kernel/loader symlink) and libm/libc (in libc6, check)
  case "$lib" in
    linux-vdso*|ld-linux*) continue;;
  esac
  if grep -qx "$lib" "$TMPHAVE"; then
    : # present
  else
    # also accept version-suffixed file providing it (e.g. libfoo.so.1.2 provides libfoo.so.1? no, need exact)
    echo "MISSING: $lib"
    miss=1
  fi
done < "$TMPNEEDED"
[ "$miss" = "0" ] && echo "(none missing)"
