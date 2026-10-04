#!/usr/bin/env bash
# Aira terminal sessions test (Wave C3): host-only unit tests for the terms
# IPC handler (direct exec), aira-term CLI fallback (no bus on host), and
# the migrated aira-terminal modes. Spawn-concurrency is guest-tested.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

H="$ROOT/initramfs/etc/aira/ipc/handlers/terms"
export AIRA_TERMS_HANDLER="$H"
export PATH="$ROOT/initramfs/usr/bin:$PATH"

echo "--- syntax ---"
for f in "$H" initramfs/usr/bin/aira-term gui/aira-terminal initramfs/sbin/guest-termtest.sh initramfs/init; do
  if sh -n "$f" 2>/dev/null; then ok "$f syntax"; else bad "$f syntax"; fi
done
grep -q '^PRIV_METHODS="spawn kill cleanup"' "$H" && ok "spawn/kill/cleanup privileged" || bad "priv methods"
if grep -q 'eval ' "$H"; then bad "no eval in handler"; else ok "no eval in handler"; fi

T="$(mktemp -d /tmp/aira-terms-test.XXXXXX)"
export AIRA_TERMS_DIR="$T/reg"
mkdir -p "$T/reg"
S() { env AIRA_TERMS_DIR="$T/reg" sh "$H" "$@"; }
C() { env AIRA_TERMS_DIR="$T/reg" sh "$ROOT/initramfs/usr/bin/aira-term" "$@"; }

echo "--- caps/list (open) ---"
S caps | grep -q "max=32" && ok "caps" || bad "caps"
S caps | grep -q "pty=kernel/xterm" && ok "caps honesty" || bad "caps honesty"
S list >/dev/null 2>&1 && ok "list empty" || bad "list empty"

echo "--- spawn validation (headless UNAVAILABLE + arg checks) ---"
if S spawn "$T|sh" >/dev/null 2>&1; then bad "headless spawn accepted"; else ok "headless spawn UNAVAILABLE"; fi
S spawn "/tmp/../etc|sh" >/dev/null 2>&1 && bad "traversal cwd" || ok "traversal cwd rejected"
S spawn "/no-such-dir-xyz|sh" >/dev/null 2>&1 && bad "missing cwd" || ok "missing cwd rejected"
S spawn "$T|/bin/sh" >/dev/null 2>&1 && bad "slashed shell" || ok "slashed shell rejected"
S spawn "$T|sh;evil" >/dev/null 2>&1 && bad "shell metachars" || ok "shell metachars rejected"
S spawn "$T|no-such-shell-xyz" >/dev/null 2>&1 && bad "missing shell" || ok "missing shell rejected"
S spawn "$T" >/dev/null 2>&1 && bad "missing shell arg" || ok "missing shell arg rejected"
S spawn "" >/dev/null 2>&1 && bad "empty args" || ok "empty args rejected"
S bogus >/dev/null 2>&1 && bad "unknown method" || ok "unknown method rejected"

echo "--- registry hygiene on fixtures ---"
sleep 30 &
LIVEPID=$!
printf "pid=%s\nuid=%s\ndisplay=\ncwd=/tmp\nshell=/bin/sh\nstarted=0\n" "$LIVEPID" "$(id -u)" > "$T/reg/live-1.session"
printf "pid=999997\nuid=%s\ndisplay=\ncwd=/tmp\nshell=/bin/sh\nstarted=0\n" "$(id -u)" > "$T/reg/stale-1.session"
printf "pid=%s\nuid=99999\ndisplay=\ncwd=/tmp\nshell=/bin/sh\nstarted=0\n" "$LIVEPID" > "$T/reg/foreign-1.session"
S list | grep -q "live-1.*live" && ok "fixture live listed" || bad "fixture live listed"
S list | grep -q "stale-1.*dead" && ok "fixture dead flagged" || bad "fixture dead flagged"
S cleanup | grep -q "removed=1" && ok "stale reaped" || bad "stale reaped"
[ ! -f "$T/reg/stale-1.session" ] && [ -f "$T/reg/live-1.session" ] && ok "selective reap" || bad "selective reap"
S kill live-1 | grep -q "signalled" && ok "kill own session" || bad "kill own session"
kill "$LIVEPID" 2>/dev/null || true
wait "$LIVEPID" 2>/dev/null || true
S kill foreign-1 >/dev/null 2>&1 && bad "cross-uid kill" || ok "cross-uid kill denied"
S kill live-1 >/dev/null 2>&1
S kill "../x" >/dev/null 2>&1 && bad "bad id" || ok "bad id rejected"
S kill t-no-such-session-0 >/dev/null 2>&1 && bad "unknown kill" || ok "unknown kill rejected"
S cleanup | grep -Eq "removed=[12]" && ok "final cleanup" || bad "final cleanup"

echo "--- CLI fallback (no bus on host) ---"
C caps | grep -q "max=32" && ok "cli caps" || bad "cli caps"
C list >/dev/null 2>&1 && ok "cli list" || bad "cli list"
C spawn "$T" sh >/dev/null 2>&1 && bad "cli headless spawn" || ok "cli headless spawn UNAVAILABLE"
C kill t-nope >/dev/null 2>&1 && bad "cli unknown kill" || ok "cli unknown kill rejected"
C bogus >/dev/null 2>&1 && bad "cli unknown" || ok "cli unknown rejected"

echo "--- terminal wrapper modes ---"
[ -x "$ROOT/gui/aira-terminal" ] && ok "terminal executable" || bad "terminal executable"
bash "$ROOT/gui/aira-terminal" --once /tmp 2>/dev/null | grep -q "^shell=" && ok "--once shell" || bad "--once shell"
bash "$ROOT/gui/aira-terminal" --once /tmp 2>/dev/null | grep -q "^session-cli=" && ok "--once cli ref" || bad "--once cli ref"
bash "$ROOT/gui/aira-terminal" --kill >/dev/null 2>&1 && bad "--kill usage" || ok "--kill usage enforced"

kill "$LIVEPID" 2>/dev/null || true
rm -rf "$T"

echo
echo "TERMS TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
