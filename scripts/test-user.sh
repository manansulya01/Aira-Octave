#!/usr/bin/env bash
# Aira user-management security test (Wave E, identity subsystem).
#
# aira-user edits /etc/passwd, /etc/shadow and /etc/group. The previous
# implementation interpolated the username into sed/grep PATTERNS and appended
# raw lines to those files, so a name containing regex metacharacters or ':'
# could rewrite the wrong accounts or corrupt the database. These tests run
# against a SANDBOX copy of the credential files (AIRA_USER_ETC) so the host
# /etc is never touched, and assert both correctness and injection refusal.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

U="$ROOT/initramfs/usr/bin/aira-user"
T="$(mktemp -d /tmp/aira-user-test.XXXXXX)"
export AIRA_USER_ETC="$T/etc"
mkdir -p "$AIRA_USER_ETC"
cat > "$AIRA_USER_ETC/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
aira:x:1000:1000:aira user:/home/aira:/bin/sh
testuser:x:1001:1001:test user:/home/testuser:/bin/sh
EOF
cat > "$AIRA_USER_ETC/shadow" <<'EOF'
root:*:19000:0:99999:7:::
aira:*:19000:0:99999:7:::
testuser:*:19000:0:99999:7:::
EOF
cat > "$AIRA_USER_ETC/group" <<'EOF'
root:x:0:
aira:x:1000:
testuser:x:1001:
sudo:x:27:aira
EOF
trap 'rm -rf "$T"' EXIT
# Run aira-user against the sandbox credential files. The script must honour
# AIRA_USER_ETC; if it does not, the test fails loudly rather than touching
# the host's /etc.
P() { sh "$U" "$@"; }
n_passwd() { grep -c . "$AIRA_USER_ETC/passwd"; }

# Home directories are created for real, so redirect them into the sandbox.
export HOME_ROOT="$T/home"
mkdir -p "$HOME_ROOT"
# Allowed roots for recursive deletion (--remove-home). aira-user refuses to
# rm -rf anything outside these prefixes; the sandbox adds its own root.
export AIRA_USER_HOME_ROOTS="/home /root /var /srv $HOME_ROOT"

echo "--- sandbox wiring ---"
if grep -q 'AIRA_USER_ETC' "$U"; then ok "aira-user honours AIRA_USER_ETC"; else bad "aira-user honours AIRA_USER_ETC (host /etc would be modified!)"; fi

echo "--- static safety assertions ---"
# No username may reach a sed/grep pattern any more.
if grep -nE '(sed|grep)[^|]*"[^"]*\$NAME' "$U" | grep -v 'awk' | grep -qv '#'; then
  bad "no \$NAME in sed/grep patterns"
  grep -nE '(sed|grep)[^|]*\$NAME' "$U" | head -3
else
  ok "no \$NAME in sed/grep patterns"
fi
grep -q 'require_name' "$U" && ok "require_name guard present" || bad "require_name guard present"
grep -q 'valid_uid' "$U" && ok "valid_uid guard present" || bad "valid_uid guard present"
grep -q 'valid_path' "$U" && ok "valid_path guard present" || bad "valid_path guard present"

echo "--- name validation (injection attempts) ---"
for badname in 'a.*' '.*' 'root.*' 'a:b' 'a b' 'user$name' 'x/y' '-lead' '' 'a`id`'; do
  if [ -z "$badname" ]; then continue; fi
  if P adduser "$badname" >/dev/null 2>&1; then
    bad "adduser rejects: '$badname'"
  else
    ok "adduser rejects: '$badname'"
  fi
done
# and the same for the other subcommands
for badname in 'a.*' 'a:b' 'root.*'; do
  P deluser "$badname" >/dev/null 2>&1 && bad "deluser rejects: '$badname'" || ok "deluser rejects: '$badname'"
  P delgroup "$badname" >/dev/null 2>&1 && bad "delgroup rejects: '$badname'" || ok "delgroup rejects: '$badname'"
  P passwd "$badname" --stdin >/dev/null 2>&1 && bad "passwd rejects: '$badname'" || ok "passwd rejects: '$badname'"
  P usermod "$badname" --uid 1500 >/dev/null 2>&1 && bad "usermod rejects: '$badname'" || ok "usermod rejects: '$badname'"
done

echo "--- credential files unchanged by injection attempts ---"
[ "$(n_passwd)" = "3" ] && ok "passwd still has 3 entries" || bad "passwd corrupted: $(n_passwd) entries"
[ "$(grep -c . "$AIRA_USER_ETC/shadow")" = "3" ] && ok "shadow unchanged" || bad "shadow corrupted"
grep -q "^root:" "$AIRA_USER_ETC/passwd" && ok "root entry intact" || bad "root entry destroyed"
grep -q "^aira:" "$AIRA_USER_ETC/passwd" && ok "aira entry intact" || bad "aira entry destroyed"
grep -q '^sudo:x:27:aira' "$AIRA_USER_ETC/group" && ok "group membership intact" || bad "group membership corrupted"

echo "--- wildcard name must not act as a pattern ---"
# A caller asking to delete "a.*" must not be able to remove aira and aira2.
printf 'a2:x:1500:1500::/home/a2:/bin/sh\n' >> "$AIRA_USER_ETC/passwd"
printf 'a2:*:19000:0:99999:7:::\n' >> "$AIRA_USER_ETC/shadow"
P deluser 'a.*' >/dev/null 2>&1
grep -q "^aira:" "$AIRA_USER_ETC/passwd" && grep -q "^a2:" "$AIRA_USER_ETC/passwd" \
  && ok "wildcard delete did not match other users" || bad "wildcard delete removed unrelated users"

echo "--- files without a trailing newline (as shipped in the image) ---"
printf 'root:x:0:0:root:/root:/bin/sh\nweird:x:1400:1400::/home/weird:/bin/sh' > "$AIRA_USER_ETC/passwd"  # no final \n
printf 'root:*:19000:0:99999:7:::\nweird:*:19000:0:99999:7:::' > "$AIRA_USER_ETC/shadow"     # no final \n
printf 'root:x:0:\nweird:x:1400:' > "$AIRA_USER_ETC/group"                                        # no final \n
P adduser nluser --uid 1401 >/dev/null 2>&1
grep -q '^weird:\*:19000:' "$AIRA_USER_ETC/shadow" && ok "existing shadow row not corrupted by append" || bad "shadow row glued: $(grep '^weird:' "$AIRA_USER_ETC/shadow")"
grep -q '^weird:x:1400:1400:' "$AIRA_USER_ETC/passwd" && ok "existing passwd row intact" || bad "passwd row corrupted"
grep -q '^nluser:\*:19000:' "$AIRA_USER_ETC/shadow" && ok "new shadow row added correctly" || bad "new shadow row missing: $(grep '^nluser' "$AIRA_USER_ETC/shadow")"
grep -q '^weird:x:1400:' "$AIRA_USER_ETC/group" && ok "existing group row intact" || bad "group row corrupted"
grep -q '^nluser:x:1401:' "$AIRA_USER_ETC/group" && ok "new group row added correctly" || bad "new group row missing"
[ "$(grep -c . "$AIRA_USER_ETC/shadow")" = "3" ] && ok "shadow row count correct" || bad "shadow row count: $(grep -c . "$AIRA_USER_ETC/shadow")"
# restore a normal sandbox for the remaining checks
cat > "$AIRA_USER_ETC/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
aira:x:1000:1000:aira user:/home/aira:/bin/sh
testuser:x:1001:1001:test user:/home/testuser:/bin/sh
a2:x:1500:1500::/home/a2:/bin/sh
EOF
cat > "$AIRA_USER_ETC/shadow" <<'EOF'
root:*:19000:0:99999:7:::
aira:*:19000:0:99999:7:::
testuser:*:19000:0:99999:7:::
a2:*:19000:0:99999:7:::
EOF
cat > "$AIRA_USER_ETC/group" <<'EOF'
root:x:0:
aira:x:1000:
testuser:x:1001:
a2:x:1500:
sudo:x:27:aira
EOF

echo "--- normal adduser works ---"
if P adduser newuser --uid 1501 >/dev/null 2>&1; then
  grep -q "^newuser:x:1501:" "$AIRA_USER_ETC/passwd" && ok "newuser in passwd" || bad "newuser in passwd"
  grep -q "^newuser:x:1501:" "$AIRA_USER_ETC/group" && ok "newuser group created" || bad "newuser group created"
  grep -q "^newuser:\*:19000:" "$AIRA_USER_ETC/shadow" && ok "newuser shadow entry" || bad "newuser shadow entry"
else
  bad "adduser newuser succeeded"
fi
P adduser newuser >/dev/null 2>&1 && bad "duplicate adduser rejected" || ok "duplicate adduser rejected"
P adduser uidclash --uid 1000 >/dev/null 2>&1 && bad "duplicate uid rejected" || ok "duplicate uid rejected"
# restored sandbox has 4 rows; the one successful adduser makes 5
[ "$(n_passwd)" = "5" ] && ok "no partial write on rejection" || bad "passwd entry count: $(n_passwd)"

echo "--- UID/GID/path validation ---"
P adduser badpath --home "relative/path" >/dev/null 2>&1 && bad "relative home rejected" || ok "relative home rejected"
P adduser badpath --home "/home/../etc" >/dev/null 2>&1 && bad "traversal home rejected" || ok "traversal home rejected"
P adduser badroot --home "/" >/dev/null 2>&1 && bad "root-directory home rejected" || ok "root-directory home rejected"
P adduser badetc --home "/etc" >/dev/null 2>&1 && bad "system-directory home rejected" || ok "system-directory home rejected"
P adduser badroot --home "/home" >/dev/null 2>&1 && bad "home-root itself rejected" || ok "home-root itself rejected"
mkdir -p "$HOME_ROOT/existing"
printf 'keep-existing-home\n' > "$HOME_ROOT/existing/marker"
P adduser existinghome --home "$HOME_ROOT/existing" >/dev/null 2>&1 && bad "existing home path refused" || ok "existing home path refused"
[ "$(cat "$HOME_ROOT/existing/marker")" = "keep-existing-home" ] && ok "existing home content preserved" || bad "existing home content preserved"
if grep -q '^existinghome:' "$AIRA_USER_ETC/passwd"; then bad "existing-home account not partially created"; else ok "existing-home account not partially created"; fi
P usermod newuser --home "/" >/dev/null 2>&1 && bad "unsafe usermod home rejected" || ok "unsafe usermod home rejected"
grep -q '^newuser:x:1501:.*:/home/newuser:/bin/sh
P adduser badpath --uid "99999" >/dev/null 2>&1 && bad "out-of-range uid rejected" || ok "out-of-range uid rejected"
P adduser badpath --shell "/bin/sh;id" >/dev/null 2>&1 && bad "shell metachars rejected" || ok "shell metachars rejected"
P adduser badpath --gecos "a:b" >/dev/null 2>&1 && bad "gecos colon rejected" || ok "gecos colon rejected"
P addgroup grp1 --gid abc >/dev/null 2>&1 && bad "group bad gid rejected" || ok "group bad gid rejected"

echo "--- passwd hashing is salted, not a bare digest ---"
printf 'hunter2hunter2\n' | P passwd newuser --stdin >/dev/null 2>&1
LINE="$(awk -F: '$1=="newuser" { print $2; exit }' "$AIRA_USER_ETC/shadow")"
case "$LINE" in
  *aira1*) ok "uses tagged hash format" ;;
  *) bad "uses tagged hash format (got: ${LINE:-none})" ;;
esac
case "$LINE" in
  *'$'*) ok "hash carries salt/params" ;;
  *) bad "hash carries salt/params" ;;
esac
case "$LINE" in
  ""|"*") bad "password actually stored" ;;
  *) ok "password actually stored" ;;
esac
# Two accounts with the SAME password must not produce the same hash (salt works).
printf 'hunter2hunter2\n' | P passwd testuser --stdin >/dev/null 2>&1
L1="$(awk -F: '$1=="newuser" { print $2; exit }' "$AIRA_USER_ETC/shadow")"
L2="$(awk -F: '$1=="testuser" { print $2; exit }' "$AIRA_USER_ETC/shadow")"
[ -n "$L1" ] && [ "$L1" != "$L2" ] && ok "identical passwords hash differently (salted)" || bad "identical passwords hash differently (salted)"
# Weak passwords refused
printf 'short\n' | P passwd newuser --stdin >/dev/null 2>&1 && bad "short password refused" || ok "short password refused"
P passwd root --stdin </dev/null >/dev/null 2>&1 && bad "root passwd refused" || ok "root passwd refused"
awk -F: '$1=="newuser" { exit ($2 ~ /^\$aira1\$/ ? 0 : 1) }' "$AIRA_USER_ETC/shadow" \
  && ok "short-password attempt did not corrupt hash" || bad "short-password attempt did not corrupt hash"

echo "--- shadow stays non-world-readable ---"
MODE="$(stat -c %a "$AIRA_USER_ETC/shadow" 2>/dev/null || echo '?')"
case "$MODE" in
  [0-7][0-7][0-7])
    if [ "$(( 8#$MODE & 0004 ))" -eq 0 ]; then
      ok "shadow mode $MODE (not world-readable)"
    else
      bad "shadow mode $MODE (is world-readable)"
    fi
    ;;
  *) bad "shadow mode $MODE" ;;
esac

echo "--- usermod correctness ---"
if P usermod newuser --uid 1502 2>&1; then
  grep -q "^newuser:x:1502:" "$AIRA_USER_ETC/passwd" && ok "usermod changed uid" || bad "usermod changed uid (line: $(grep '^newuser:' "$AIRA_USER_ETC/passwd"))"
else
  bad "usermod newuser --uid 1502 succeeded"
fi
P usermod newuser --lock >/dev/null 2>&1
awk -F: '$1=="newuser" { exit ($2=="!" ? 0 : 1) }' "$AIRA_USER_ETC/shadow" \
  && ok "lock sets ! marker" || bad "lock sets ! marker"
P usermod newuser --unlock >/dev/null 2>&1
awk -F: '$1=="newuser" { exit ($2=="*" ? 0 : 1) }' "$AIRA_USER_ETC/shadow" \
  && ok "unlock resets to *" || bad "unlock resets to *"
P usermod newuser --lock --unlock >/dev/null 2>&1 && bad "lock+unlock rejected" || ok "lock+unlock rejected"
P usermod root --uid 0 --home /root >/dev/null 2>&1
grep -q "^root:x:0:0:root:/root:/bin/sh$" "$AIRA_USER_ETC/passwd" && ok "root line unchanged" || bad "root line changed: $(grep '^root:' "$AIRA_USER_ETC/passwd")"

echo "--- deluser safety ---"
if P adduser doomed --home "$HOME_ROOT/doomed" >/dev/null 2>&1; then
  mkdir -p "$HOME_ROOT/doomed"
  printf 'x\n' > "$HOME_ROOT/doomed/file"
  if P deluser doomed --remove-home >/dev/null 2>&1; then
    grep -q "^doomed:" "$AIRA_USER_ETC/passwd" && bad "doomed removed from passwd" || ok "doomed removed from passwd"
    [ -d "$HOME_ROOT/doomed" ] && bad "home removed" || ok "home removed"
  else
    bad "deluser doomed succeeded"
  fi
else
  bad "adduser doomed succeeded"
fi
# A user whose home is "/" must not cause a recursive delete of the root fs.
printf 'danger:x:1601:1601::/:/bin/sh\n' >> "$AIRA_USER_ETC/passwd"
printf 'danger:*:19000:0:99999:7:::\n' >> "$AIRA_USER_ETC/shadow"
P deluser danger --remove-home >/dev/null 2>&1
[ -d "$T/etc" ] && ok "refused to rm -rf an unsafe home" || bad "deleted an unsafe home path"

echo "--- delgroup correctness ---"
P addgroup devgroup >/dev/null 2>&1 && ok "addgroup" || bad "addgroup"
P delgroup devgroup >/dev/null 2>&1 && ok "delgroup" || bad "delgroup"
grep -q "^devgroup:" "$AIRA_USER_ETC/group" && bad "devgroup removed" || ok "devgroup removed"
P delgroup testuser >/dev/null 2>&1 && bad "primary group protected" || ok "primary group protected"
grep -q "^testuser:" "$AIRA_USER_ETC/group" && ok "testuser group still present" || bad "testuser group deleted!"
grep -q '^sudo:x:27:aira' "$AIRA_USER_ETC/group" && ok "supplementary membership preserved" || bad "supplementary membership lost"

echo
echo "USER TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ] "$AIRA_USER_ETC/passwd" && ok "rejected usermod leaves home unchanged" || bad "rejected usermod leaves home unchanged"
P adduser badpath --uid "abc" >/dev/null 2>&1 && bad "non-numeric uid rejected" || ok "non-numeric uid rejected"
P adduser badpath --uid "99999" >/dev/null 2>&1 && bad "out-of-range uid rejected" || ok "out-of-range uid rejected"
P adduser badpath --shell "/bin/sh;id" >/dev/null 2>&1 && bad "shell metachars rejected" || ok "shell metachars rejected"
P adduser badpath --gecos "a:b" >/dev/null 2>&1 && bad "gecos colon rejected" || ok "gecos colon rejected"
P addgroup grp1 --gid abc >/dev/null 2>&1 && bad "group bad gid rejected" || ok "group bad gid rejected"

echo "--- passwd hashing is salted, not a bare digest ---"
printf 'hunter2hunter2\n' | P passwd newuser --stdin >/dev/null 2>&1
LINE="$(awk -F: '$1=="newuser" { print $2; exit }' "$AIRA_USER_ETC/shadow")"
case "$LINE" in
  *aira1*) ok "uses tagged hash format" ;;
  *) bad "uses tagged hash format (got: ${LINE:-none})" ;;
esac
case "$LINE" in
  *'$'*) ok "hash carries salt/params" ;;
  *) bad "hash carries salt/params" ;;
esac
case "$LINE" in
  ""|"*") bad "password actually stored" ;;
  *) ok "password actually stored" ;;
esac
# Two accounts with the SAME password must not produce the same hash (salt works).
printf 'hunter2hunter2\n' | P passwd testuser --stdin >/dev/null 2>&1
L1="$(awk -F: '$1=="newuser" { print $2; exit }' "$AIRA_USER_ETC/shadow")"
L2="$(awk -F: '$1=="testuser" { print $2; exit }' "$AIRA_USER_ETC/shadow")"
[ -n "$L1" ] && [ "$L1" != "$L2" ] && ok "identical passwords hash differently (salted)" || bad "identical passwords hash differently (salted)"
# Weak passwords refused
printf 'short\n' | P passwd newuser --stdin >/dev/null 2>&1 && bad "short password refused" || ok "short password refused"
P passwd root --stdin </dev/null >/dev/null 2>&1 && bad "root passwd refused" || ok "root passwd refused"
awk -F: '$1=="newuser" { exit ($2 ~ /^\$aira1\$/ ? 0 : 1) }' "$AIRA_USER_ETC/shadow" \
  && ok "short-password attempt did not corrupt hash" || bad "short-password attempt did not corrupt hash"

echo "--- shadow stays non-world-readable ---"
MODE="$(stat -c %a "$AIRA_USER_ETC/shadow" 2>/dev/null || echo '?')"
case "$MODE" in
  [0-7][0-7][0-7])
    if [ "$(( 8#$MODE & 0004 ))" -eq 0 ]; then
      ok "shadow mode $MODE (not world-readable)"
    else
      bad "shadow mode $MODE (is world-readable)"
    fi
    ;;
  *) bad "shadow mode $MODE" ;;
esac

echo "--- usermod correctness ---"
if P usermod newuser --uid 1502 2>&1; then
  grep -q "^newuser:x:1502:" "$AIRA_USER_ETC/passwd" && ok "usermod changed uid" || bad "usermod changed uid (line: $(grep '^newuser:' "$AIRA_USER_ETC/passwd"))"
else
  bad "usermod newuser --uid 1502 succeeded"
fi
P usermod newuser --lock >/dev/null 2>&1
awk -F: '$1=="newuser" { exit ($2=="!" ? 0 : 1) }' "$AIRA_USER_ETC/shadow" \
  && ok "lock sets ! marker" || bad "lock sets ! marker"
P usermod newuser --unlock >/dev/null 2>&1
awk -F: '$1=="newuser" { exit ($2=="*" ? 0 : 1) }' "$AIRA_USER_ETC/shadow" \
  && ok "unlock resets to *" || bad "unlock resets to *"
P usermod newuser --lock --unlock >/dev/null 2>&1 && bad "lock+unlock rejected" || ok "lock+unlock rejected"
P usermod root --uid 0 --home /root >/dev/null 2>&1
grep -q "^root:x:0:0:root:/root:/bin/sh$" "$AIRA_USER_ETC/passwd" && ok "root line unchanged" || bad "root line changed: $(grep '^root:' "$AIRA_USER_ETC/passwd")"

echo "--- deluser safety ---"
mkdir -p "$HOME_ROOT/doomed"
printf 'x\n' > "$HOME_ROOT/doomed/file"
P adduser doomed --home "$HOME_ROOT/doomed" >/dev/null 2>&1
if P deluser doomed --remove-home >/dev/null 2>&1; then
  grep -q "^doomed:" "$AIRA_USER_ETC/passwd" && bad "doomed removed from passwd" || ok "doomed removed from passwd"
  [ -d "$HOME_ROOT/doomed" ] && bad "home removed" || ok "home removed"
else
  bad "deluser doomed succeeded"
fi
# A user whose home is "/" must not cause a recursive delete of the root fs.
printf 'danger:x:1601:1601::/:/bin/sh\n' >> "$AIRA_USER_ETC/passwd"
printf 'danger:*:19000:0:99999:7:::\n' >> "$AIRA_USER_ETC/shadow"
P deluser danger --remove-home >/dev/null 2>&1
[ -d "$T/etc" ] && ok "refused to rm -rf an unsafe home" || bad "deleted an unsafe home path"

echo "--- delgroup correctness ---"
P addgroup devgroup >/dev/null 2>&1 && ok "addgroup" || bad "addgroup"
P delgroup devgroup >/dev/null 2>&1 && ok "delgroup" || bad "delgroup"
grep -q "^devgroup:" "$AIRA_USER_ETC/group" && bad "devgroup removed" || ok "devgroup removed"
P delgroup testuser >/dev/null 2>&1 && bad "primary group protected" || ok "primary group protected"
grep -q "^testuser:" "$AIRA_USER_ETC/group" && ok "testuser group still present" || bad "testuser group deleted!"
grep -q '^sudo:x:27:aira' "$AIRA_USER_ETC/group" && ok "supplementary membership preserved" || bad "supplementary membership lost"

echo
echo "USER TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]