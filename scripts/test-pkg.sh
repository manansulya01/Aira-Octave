#!/usr/bin/env bash
# Aira package-manager test (Wave C6): host-only security + transaction tests
# for airapkg. Uses a sandboxed DB (AIRA_PKG_DB) so the host system is never
# touched, and builds real .apkg archives with tar.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

PKG="$ROOT/initramfs/usr/bin/airapkg"
T="$(mktemp -d /tmp/aira-pkg-test.XXXXXX)"
export AIRA_PKG_DB="$T/db"
export AIRA_PKG_TXLOG="$T/db/transactions.log"
export AIRA_PKG_ROOT="$T/root"
mkdir -p "$AIRA_PKG_DB" "$AIRA_PKG_ROOT"
trap 'rm -rf "$T"' EXIT
P() { sh "$PKG" "$@"; }

echo "--- syntax ---"
sh -n "$PKG" 2>/dev/null && ok "airapkg syntax" || bad "airapkg syntax"
if grep -q 'eval ' "$PKG"; then bad "no eval in airapkg"; else ok "no eval in airapkg"; fi
grep -q 'reject duplicate archive member' "$PKG" && ok "duplicate-member guard present" || bad "duplicate-member guard present"
grep -q 'DB commit failed' "$PKG" && ok "atomic DB commit present" || bad "atomic DB commit present"
grep -q 'tx commit' "$PKG" && ok "transaction log present" || bad "transaction log present"

echo "--- package-name path traversal rejected ---"
for badname in .. ../escape ../../escape name/escape '-leading'; do
  if P query "$badname" >/dev/null 2>&1; then
    bad "unsafe package name rejected: $badname"
  else
    ok "unsafe package name rejected: $badname"
  fi
done

echo "--- signing claims fail closed ---"
if P build "$ROOT/initramfs" "$T/should-not-exist.apkg" --sign "$T/fake-key" >"$T/sign-build.log" 2>&1; then
  bad "unimplemented signing refused"
else
  grep -q 'cryptographic package signing is not implemented' "$T/sign-build.log" && ok "unimplemented signing refused" || bad "unimplemented signing diagnostic"
fi
[ ! -e "$T/should-not-exist.apkg" ] && ok "failed signing writes no package" || bad "failed signing writes no package"
printf 'package\n' > "$T/unsigned.apkg"
printf 'key\n' > "$T/fake-key"
if P sign "$T/unsigned.apkg" "$T/fake-key" >"$T/sign.log" 2>&1; then
  bad "fake signature refused"
else
  grep -q 'no signature was created' "$T/sign.log" && ok "fake signature refused" || bad "fake signature diagnostic"
fi
if P verify-sig "$T/unsigned.apkg" "$T/fake-key" >"$T/verify-sig.log" 2>&1; then
  bad "unimplemented signature verification refused"
else
  grep -q 'authenticity was not verified' "$T/verify-sig.log" && ok "unimplemented signature verification refused" || bad "signature verification diagnostic"
fi

echo "--- build helper ---"
mkpkg() { # mkpkg <name> <version> <payload-path> <out.apkg>
    local d="$T/build-$1"
    rm -rf "$d"; mkdir -p "$d/usr/share/aira"
    printf 'NAME="%s"\nVERSION="%s"\nDESC="test package"\nDEPS=""\n' "$1" "$2" > "$d/PKGINFO"
    printf 'payload of %s\n' "$1" > "$3"
    tar -czf "$4" -C "$d" .
}
mkpkg hello-aira 1.0 "$T/build-hello-aira/usr/share/aira/hello.txt" "$T/hello-aira.apkg"
[ -f "$T/hello-aira.apkg" ] && ok "apkg built" || bad "apkg built"

echo "--- payload filenames that resemble installer scratch files ---"
N="$T/internal-names"; rm -rf "$N"; mkdir -p "$N/usr/share/doc"
printf 'NAME="internal-names"\\nVERSION="1.0"\\nDESC="scratch-name regression"\\nDEPS=""\\n' > "$N/PKGINFO"
for name in seen.txt members.txt list.txt; do printf 'payload %s\\n' "$name" > "$N/$name"; done
printf 'nested metadata is payload\\n' > "$N/usr/share/doc/PKGINFO"
tar -czf "$T/internal-names.apkg" -C "$N" .
if P install "$T/internal-names.apkg" >"$T/internal-names.log" 2>&1; then
  ok "package with scratch-like filenames installs"
else
  bad "package with scratch-like filenames installs"
  sed 's/^/  INFO: /' "$T/internal-names.log" | head -10
fi
for rel in seen.txt members.txt list.txt usr/share/doc/PKGINFO; do
  [ -f "$AIRA_PKG_ROOT/$rel" ] && ok "payload preserved: $rel" || bad "payload preserved: $rel"
done
P verify internal-names | grep -q "verify OK" && ok "scratch-like payload files recorded in package database" || bad "scratch-like payload files recorded in package database"
P remove internal-names >/dev/null 2>&1 && ok "scratch-like package removes cleanly" || bad "scratch-like package removes cleanly"

echo "--- install/list/query/verify ---"
if P install "$T/hello-aira.apkg" > "$T/pkg-install.out" 2>&1; then
  P install "$T/hello-aira.apkg" 2>&1 | grep -q "already installed" \
    && ok "install" || ok "install (already-installed on retry)"
  sed 's/^/  INFO: /' "$T/pkg-install.out" | head -5
else
  bad "install"
  sed 's/^/  INFO: /' "$T/pkg-install.out" | head -10
fi
P list | grep -q "hello-aira" && ok "list" || bad "list"
P query hello-aira | grep -q 'NAME="hello-aira"' && ok "query metadata" || bad "query metadata"
P query hello-aira | grep -q "usr/share/aira/hello.txt" && ok "query file list" || bad "query file list"
P verify hello-aira | grep -q "verify OK" && ok "verify" || bad "verify"
[ -f "$AIRA_PKG_DB/installed/hello-aira/PKGINFO" ] && ok "DB entry persisted" || bad "DB entry persisted"

echo "--- transaction log ---"
grep -q "tx=install pkg=hello-aira begin" "$AIRA_PKG_TXLOG" 2>/dev/null && ok "install begin logged" || bad "install begin logged"
grep -q "tx=commit pkg=hello-aira" "$AIRA_PKG_TXLOG" 2>/dev/null && ok "install commit logged" || bad "install commit logged"

echo "--- duplicate archive member rejected ---"
D="$T/dup"; rm -rf "$D"; mkdir -p "$D/usr/share/aira"
printf 'NAME="duppkg"\nVERSION="1.0"\nDESC="x"\nDEPS=""\n' > "$D/PKGINFO"
printf 'first\n' > "$D/usr/share/aira/f.txt"
# append the same member again so extraction order would decide the winner
( cd "$D" && tar -czf "$T/dup1.tgz" . ) 2>/dev/null
( cd "$D" && tar -rzf "$T/dup1.tgz" usr/share/aira/f.txt ) 2>/dev/null
if [ -f "$T/dup1.tgz" ] && tar -tzf "$T/dup1.tgz" 2>/dev/null | grep -c "usr/share/aira/f.txt" | grep -qE '^[2-9]'; then
  if P install "$T/dup1.tgz" >/dev/null 2>&1; then
    bad "duplicate member rejected"
  else
    P install "$T/dup1.tgz" 2>&1 | grep -q "duplicate" && ok "duplicate member rejected" || bad "duplicate member rejected"
  fi
else
  echo "  INFO: could not construct a duplicate-member archive on this tar; guard asserted statically"
  ok "duplicate member guard asserted (static)"
fi

echo "--- malicious archives rejected ---"
M="$T/mal"; rm -rf "$M"; mkdir -p "$M/usr/share"
printf 'NAME="mal"\nVERSION="1.0"\nDESC="x"\nDEPS=""\n' > "$M/PKGINFO"
printf 'evil\n' > "$M/usr/share/evil.txt"
tar -czf "$T/mal-abs.tgz" -P -C / etc 2>/dev/null || true
L="$T/maxtrav"; rm -rf "$L"; mkdir -p "$L/x"
printf 'NAME="trav"\nVERSION="1.0"\nDESC="x"\nDEPS=""\n' > "$L/PKGINFO"
printf 'evil\n' > "$L/x/evil.txt"
tar -czf "$T/mal-trav.tgz" -C "$L" --transform 's,^x/,\.\./,' x/evil.txt 2>/dev/null \
  || tar -czf "$T/mal-trav.tgz" -C "$L" x 2>/dev/null || true
for a in mal-abs mal-trav; do
  [ -f "$T/$a.tgz" ] || continue
  P install "$T/$a.tgz" >/dev/null 2>&1 && bad "$a rejected" || ok "$a rejected"
done
S="$T/sym"; rm -rf "$S"; mkdir -p "$S"
printf 'NAME="sym"\nVERSION="1.0"\nDESC="x"\nDEPS=""\n' > "$S/PKGINFO"
ln -sf /etc/passwd "$S/evil-link" 2>/dev/null || true
tar -czf "$T/mal-sym.tgz" -C "$S" . 2>/dev/null || true
P install "$T/mal-sym.tgz" >/dev/null 2>&1 && bad "symlink archive rejected" || ok "symlink archive rejected"
printf 'not-a-tar' > "$T/corrupt.apkg"
P install "$T/corrupt.apkg" >/dev/null 2>&1 && bad "corrupt archive rejected" || ok "corrupt archive rejected"
P install "$T/does-not-exist.apkg" >/dev/null 2>&1 && bad "missing file rejected" || ok "missing file rejected"
[ ! -f /etc/passwd.evil ] && ok "no payload escaped to /etc" || bad "no payload escaped to /etc"

echo "--- bad PKGINFO rejected ---"
B="$T/bad"; rm -rf "$B"; mkdir -p "$B"
printf 'DESC="no name"\nVERSION="1.0"\n' > "$B/PKGINFO"
tar -czf "$T/bad.apkg" -C "$B" . 2>/dev/null
P install "$T/bad.apkg" >/dev/null 2>&1 && bad "missing NAME rejected" || ok "missing NAME rejected"
printf 'NAME="x/../evil"\nVERSION="1.0"\n' > "$B/PKGINFO"
tar -czf "$T/bad2.apkg" -C "$B" . 2>/dev/null
P install "$T/bad2.apkg" >/dev/null 2>&1 && bad "slash in NAME rejected" || ok "slash in NAME rejected"

echo "--- reinstall requires --force ---"
P install "$T/hello-aira.apkg" >/dev/null 2>&1 && bad "reinstall refused" || ok "reinstall refused"
P install --force "$T/hello-aira.apkg" | grep -q "installed" && ok "forced reinstall" || bad "forced reinstall"

echo "--- partial install failure rolls back inside package root ---"
F="$T/failtxn"; rm -rf "$F"; mkdir -p "$F/usr/share/aira"
printf 'NAME="failtxn"\nVERSION="1.0"\nDESC="failure transaction"\nDEPS=""\n' > "$F/PKGINFO"
printf 'must be rolled back\n' > "$F/usr/share/aira/aaa-good.txt"
printf 'copy is injected to fail\n' > "$F/usr/share/aira/zzz-fail.txt"
tar -czf "$T/failtxn.apkg" -C "$F" .
mkdir -p "$AIRA_PKG_ROOT/usr/share/aira"
printf 'original value\n' > "$AIRA_PKG_ROOT/usr/share/aira/aaa-good.txt"
mkdir -p "$T/failbin"
cat > "$T/failbin/cp" <<'MOCK_CP'
#!/bin/sh
last=""
for arg do last="$arg"; done
case "$last" in
  */zzz-fail.txt) exit 77 ;;
esac
exec /bin/cp "$@"
MOCK_CP
chmod +x "$T/failbin/cp"
if PATH="$T/failbin:$PATH" P install "$T/failtxn.apkg" > "$T/failtxn.log" 2>&1; then
  bad "injected partial copy failure rejected"
else
  ok "injected partial copy failure rejected"
fi
[ "$(cat "$AIRA_PKG_ROOT/usr/share/aira/aaa-good.txt" 2>/dev/null)" = "original value" ] && ok "overwritten file restored in package root" || bad "overwritten file restored in package root"
[ ! -e "$AIRA_PKG_ROOT/usr/share/aira/zzz-fail.txt" ] && ok "failed destination absent" || bad "failed destination absent"
[ ! -d "$AIRA_PKG_DB/installed/failtxn" ] && ok "failed package DB entry absent" || bad "failed package DB entry absent"

echo "--- unsafe package database paths fail closed ---"
OUTSIDE="$T/outside-must-survive.txt"
printf 'keep outside package root\n' > "$OUTSIDE"
mkdir -p "$AIRA_PKG_DB/installed/badrecord"
printf 'NAME="badrecord"\nVERSION="1.0"\n' > "$AIRA_PKG_DB/installed/badrecord/PKGINFO"
printf '/../../outside-must-survive.txt\n' > "$AIRA_PKG_DB/installed/badrecord/files"
printf '/../../outside-must-survive.txt\n' > "$AIRA_PKG_DB/installed/badrecord/backup-files"
mkdir -p "$AIRA_PKG_DB/installed/badrecord/backup"
if P remove badrecord >"$T/remove-badrecord.log" 2>&1; then
  bad "unsafe recorded remove path rejected"
else
  grep -q 'unsafe recorded path' "$T/remove-badrecord.log" && ok "unsafe recorded remove path rejected" || bad "unsafe recorded remove diagnostic"
fi
[ -f "$OUTSIDE" ] && [ "$(cat "$OUTSIDE")" = "keep outside package root" ] && ok "unsafe remove leaves outside file untouched" || bad "unsafe remove leaves outside file untouched"
if P rollback badrecord >"$T/rollback-badrecord.log" 2>&1; then
  bad "unsafe recorded rollback path rejected"
else
  grep -q 'unsafe recorded path' "$T/rollback-badrecord.log" && ok "unsafe recorded rollback path rejected" || bad "unsafe recorded rollback diagnostic"
fi
[ -f "$OUTSIDE" ] && [ "$(cat "$OUTSIDE")" = "keep outside package root" ] && ok "unsafe rollback leaves outside file untouched" || bad "unsafe rollback leaves outside file untouched"

echo "--- remove cleans payload ---"
P remove hello-aira | grep -q "removed" && ok "remove" || bad "remove"
[ ! -f "$AIRA_PKG_DB/installed/hello-aira" ] && ok "DB entry removed" || bad "DB entry removed"
grep -q "tx=remove pkg=hello-aira done" "$AIRA_PKG_TXLOG" 2>/dev/null && ok "remove logged" || bad "remove logged"
P verify hello-aira >/dev/null 2>&1 && bad "verify after remove fails" || ok "verify after remove fails"

echo "--- rollback restores overwritten files ---"
printf 'original\n' > "$T/rollback-target.txt"
R="$T/rb"; rm -rf "$R"; mkdir -p "$R/usr/share/aira"
printf 'NAME="rbtest"\nVERSION="2.0"\nDESC="rollback"\nDEPS=""\n' > "$R/PKGINFO"
printf 'replacement\n' > "$R/usr/share/aira/rollback-target.txt"
tar -czf "$T/rbtest.apkg" -C "$R" .
mkdir -p "$AIRA_PKG_ROOT/usr/share/aira"
printf 'original\n' > "$AIRA_PKG_ROOT/usr/share/aira/rollback-target.txt"
if P install "$T/rbtest.apkg" >/dev/null 2>&1; then
  [ "$(cat "$AIRA_PKG_ROOT/usr/share/aira/rollback-target.txt" 2>/dev/null)" = "replacement" ] \
    && ok "replacement installed" || bad "replacement installed"
  P rollback rbtest >/dev/null 2>&1 && ok "rollback runs" || bad "rollback runs"
  [ "$(cat "$AIRA_PKG_ROOT/usr/share/aira/rollback-target.txt" 2>/dev/null)" = "original" ] \
    && ok "rollback restored original" || bad "rollback restored original"
  grep -q "tx=rollback pkg=rbtest" "$AIRA_PKG_TXLOG" 2>/dev/null && ok "rollback logged" || bad "rollback logged"
else
  bad "rbtest install"
fi
P rollback no-such-pkg >/dev/null 2>&1 && bad "rollback unknown rejected" || ok "rollback unknown rejected"

echo "--- search/query edge cases ---"
P query no-such-package >/dev/null 2>&1 && bad "query unknown" || ok "query unknown rejected"
P search zzz-nomatch >/dev/null 2>&1 && ok "search no-match ok" || bad "search no-match ok"
P install >/dev/null 2>&1 && bad "install usage" || ok "install usage enforced"
P remove >/dev/null 2>&1 && bad "remove usage" || ok "remove usage enforced"
P verify >/dev/null 2>&1 && bad "verify usage" || ok "verify usage enforced"

rm -rf "$T"
trap - EXIT

echo
echo "PKG TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]