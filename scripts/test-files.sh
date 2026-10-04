#!/usr/bin/env bash
# Aira files test (Wave C1): host-only unit + attack tests for the IPC
# "files" service, aira-files CLI (local fallback path — no bus on host),
# and the migrated file manager --once mode. Fails on first error count.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

H="$ROOT/initramfs/etc/aira/ipc/handlers/files"
CLI="$ROOT/initramfs/usr/bin/aira-files"
export AIRA_FILES_HANDLER="$H"
export PATH="$ROOT/initramfs/usr/bin:$PATH"

echo "--- syntax (sh -n) ---"
for f in "$H" "$CLI" gui/aira-file-manager initramfs/sbin/guest-fileops.sh; do
  if sh -n "$f" 2>/dev/null; then ok "$f syntax"; else bad "$f syntax"; fi
done

echo "--- handler contract ---"
grep -q '^PRIV_METHODS="mkdir rename copy move delete"' "$H" && ok "writes privileged" || bad "writes privileged"
grep -q 'caps|list|stat|mkdir|rename|copy|move|delete' "$H" && ok "methods enumerated" || bad "methods enumerated"
if grep -q 'eval ' "$H"; then bad "no eval in handler"; else ok "no eval in handler"; fi

T="$(mktemp -d /tmp/aira-files-test.XXXXXX)"
trap 'rm -rf "$T"' EXIT
F() { sh "$H" "$@"; }

echo "--- happy path (direct handler) ---"
F caps | grep -q "methods=" && ok "caps" || bad "caps"
F mkdir "$T/d1" >/dev/null 2>&1 && [ -d "$T/d1" ] && ok "mkdir" || bad "mkdir"
echo "hello" > "$T/d1/note.txt"
F list "$T/d1" | grep -q "note.txt" && ok "list" || bad "list"
F list "$T/d1" | grep -q "|file|" && ok "list typed entry" || bad "list typed entry"
F stat "$T/d1/note.txt" | grep -q "|file|" && ok "stat file" || bad "stat file"
F stat "$T/d1" | grep -q "|dir|" && ok "stat dir" || bad "stat dir"
F rename "$T/d1/note.txt|$T/d1/ren.txt" >/dev/null 2>&1 && [ -f "$T/d1/ren.txt" ] && [ ! -e "$T/d1/note.txt" ] && ok "rename atomic" || bad "rename atomic"
F copy "$T/d1/ren.txt|$T/d1/cp.txt" >/dev/null 2>&1 && [ -f "$T/d1/cp.txt" ] && ok "copy" || bad "copy"
[ "$(cat "$T/d1/cp.txt")" = "hello" ] && ok "copy content" || bad "copy content"
F move "$T/d1/cp.txt|$T/d1/mv.txt" >/dev/null 2>&1 && [ -f "$T/d1/mv.txt" ] && [ ! -e "$T/d1/cp.txt" ] && ok "move" || bad "move"
F delete "$T/d1/mv.txt" >/dev/null 2>&1 && [ ! -e "$T/d1/mv.txt" ] && ok "delete file" || bad "delete file"

echo "--- hidden files ---"
touch "$T/d1/.hid"
F list "$T/d1" | grep -q ".hid" && bad "hidden shown by default" || ok "hidden hidden by default"
F list "$T/d1|1" | grep -q ".hid" && ok "hidden with flag" || bad "hidden with flag"
rm -f "$T/d1/.hid"

echo "--- no-clobber + empty-dir rules ---"
echo "a" > "$T/d1/a.txt"; echo "b" > "$T/d1/b.txt"
F rename "$T/d1/a.txt|$T/d1/b.txt" >/dev/null 2>&1 && bad "rename clobber" || ok "rename no clobber"
[ "$(cat "$T/d1/b.txt")" = "b" ] && ok "clobber victim intact" || bad "clobber victim intact"
F copy "$T/d1/a.txt|$T/d1/b.txt" >/dev/null 2>&1 && bad "copy clobber" || ok "copy no clobber"
F move "$T/d1/a.txt|$T/d1/b.txt" >/dev/null 2>&1 && bad "move clobber" || ok "move no clobber"
F delete "$T/d1" >/dev/null 2>&1 && bad "non-empty delete" || ok "non-empty refused"
rm -f "$T/d1/a.txt" "$T/d1/b.txt" "$T/d1/ren.txt"
F delete "$T/d1" >/dev/null 2>&1 && [ ! -e "$T/d1" ] && ok "empty rmdir" || bad "empty rmdir"
F mkdir "$T/d1" >/dev/null 2>&1
F mkdir "$T/d1" >/dev/null 2>&1 && bad "mkdir exists" || ok "mkdir exists rejected"

echo "--- failure hygiene ---"
F copy "$T/d1/ren.txt|$T/d1/nodir/f.txt" >/dev/null 2>&1 && bad "copy missing parent" || ok "copy missing parent rejected"
[ ! -e "$T/d1/nodir" ] && ok "no partial dir created" || bad "no partial dir created"
F stat "$T/d1/nope.txt" >/dev/null 2>&1 && bad "stat missing" || ok "stat missing rejected"
F list "$T/d1/ren.txt" >/dev/null 2>&1 && bad "list on file" || ok "list on file rejected"
F delete "$T/d1/nope.txt" >/dev/null 2>&1 && bad "delete missing" || ok "delete missing rejected"

echo "--- path attacks (must all fail) ---"
F list "$T/../etc" >/dev/null 2>&1 && bad "traversal" || ok "traversal rejected"
F list "$T/d1/../../etc" >/dev/null 2>&1 && bad "deep traversal" || ok "deep traversal rejected"
F stat "$T/%2e%2e/etc/passwd" >/dev/null 2>&1 && bad "encoded traversal" || ok "encoded traversal rejected"
F stat "$T/%2Fetc%2Fpasswd" >/dev/null 2>&1 && bad "encoded slash" || ok "encoded slash rejected"
F stat "$T/%00" >/dev/null 2>&1 && bad "encoded nul" || ok "encoded nul rejected"
F stat 'rel/path' >/dev/null 2>&1 && bad "relative path" || ok "relative rejected"
F stat "/tmp/a|b" >/dev/null 2>&1 && bad "pipe in path" || ok "pipe rejected"
F stat "" >/dev/null 2>&1 && bad "empty path" || ok "empty rejected"
F mkdir "/sbin/aira-files-evil" >/dev/null 2>&1 && bad "writable roots" || ok "outside roots denied"
[ ! -e "/sbin/aira-files-evil" ] && ok "no escape artifact" || bad "no escape artifact"
F stat "/run/aira-ipc/root.token" >/dev/null 2>&1 && bad "token read" || ok "token denied"
F stat "/etc/shadow" >/dev/null 2>&1 && bad "shadow read" || ok "shadow denied"
ln -sf /etc/shadow "$T/d1/shlink" 2>/dev/null
F stat "$T/d1/shlink" >/dev/null 2>&1 && bad "symlink escape" || ok "symlink escape denied"
rm -f "$T/d1/shlink"
ln -sf /etc/shadow "$T/d1/l.txt" 2>/dev/null
F copy "$T/d1/l.txt" "$T/d1/lcopy.txt" >/dev/null 2>&1 && bad "symlink copy" || ok "symlink source refused"
rm -f "$T/d1/l.txt" "$T/d1/lcopy.txt"

echo "--- spaces in names ---"
echo "sp" > "$T/d1/with space.txt"
F stat "$T/d1/with space.txt" | grep -q "|file|" && ok "stat spaced name" || bad "stat spaced name"
F rename "$T/d1/with space.txt|$T/d1/nospace.txt" >/dev/null 2>&1 && [ -f "$T/d1/nospace.txt" ] && ok "rename spaced name" || bad "rename spaced name"
rm -f "$T/d1/nospace.txt"

echo "--- CLI local fallback (no bus on host) ---"
sh "$CLI" caps | grep -q "methods=" && ok "cli caps fallback" || bad "cli caps fallback"
sh "$CLI" mkdir "$T/cli1" >/dev/null 2>&1 && [ -d "$T/cli1" ] && ok "cli mkdir fallback" || bad "cli mkdir fallback"
echo "c" > "$T/cli1/f.txt"
sh "$CLI" list "$T/cli1" | grep -q "f.txt" && ok "cli list fallback" || bad "cli list fallback"
sh "$CLI" list "$T/../etc" >/dev/null 2>&1 && bad "cli traversal" || ok "cli traversal rejected"
sh "$CLI" bogus >/dev/null 2>&1 && bad "cli unknown cmd" || ok "cli unknown rejected"

echo "--- file manager --once ---"
[ -x "$ROOT/gui/aira-file-manager" ] && ok "manager executable" || bad "manager executable"
bash "$ROOT/gui/aira-file-manager" --once "$T/cli1" 2>/dev/null | grep -q "f.txt" && ok "manager --once lists" || bad "manager --once lists"
bash "$ROOT/gui/aira-file-manager" --once "$T/../etc" >/dev/null 2>&1 && bad "manager traversal" || ok "manager traversal rejected"

rm -rf "$T"
trap - EXIT

echo
echo "FILES TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
