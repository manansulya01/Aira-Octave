#!/bin/sh
# In-guest identity/user-management verification (runs as init when
# aira_usertest=1). Unlike the host suite, this exercises the REAL /etc on the
# live initramfs, proving aira-user works against an actual credential
# database and that integrity survives a real boot. Prints USERTEST markers,
# then poweroff.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export TERM=linux
PASS=1
ok()   { echo "USERTEST OK: $1"; }
bad()  { echo "USERTEST FAIL: $1"; PASS=0; }
echo "===== USERTEST START ====="

U=/usr/bin/aira-user
[ -x "$U" ] && ok "aira-user present" || { bad "aira-user missing"; echo "===== USERTEST FAIL ====="; poweroff -f 2>/dev/null; sleep 5; exit 1; }
# Every row must be well-formed, and the database must be terminated properly
# before we start modifying it.
awk -F: 'NF!=7 {bad=1} END{exit bad+0}' /etc/passwd && ok "passwd rows have 7 fields" || bad "passwd row with wrong field count"
awk -F: '$1!="" {n++} END{exit (n>0 ? 0 : 1)}' /etc/shadow && ok "shadow has named rows" || bad "shadow has no named rows"

# Snapshot the database so a failure cannot leave the guest unusable.
cp /etc/passwd /tmp/passwd.bak 2>/dev/null
cp /etc/shadow /tmp/shadow.bak 2>/dev/null
cp /etc/group  /tmp/group.bak 2>/dev/null
restore() {
    cat /tmp/passwd.bak > /etc/passwd 2>/dev/null
    cat /tmp/shadow.bak > /etc/shadow 2>/dev/null
    cat /tmp/group.bak  > /etc/group  2>/dev/null
    chmod 640 /etc/shadow 2>/dev/null
}

# --- baseline: the shipped accounts must be well-formed ---
awk -F: 'NF>0 && $1=="" {bad=1} END{exit bad+0}' /etc/passwd && ok "passwd has no nameless entries" || bad "passwd has a nameless entry"
awk -F: 'NF!=7 {bad=1} END{exit bad+0}' /etc/passwd && ok "passwd rows have 7 fields" || bad "passwd row with wrong field count"
grep -q '^aira:' /etc/passwd && ok "aira user exists" || bad "aira user missing"
grep -q '^root:' /etc/passwd && ok "root exists" || bad "root missing"
awk -F: '$3==0 {print $1}' /etc/passwd | grep -qx root && ok "uid 0 is root" || bad "uid 0 is not root"

# --- injection attempts must be refused and change nothing ---
_BEFORE="$(cat /etc/passwd /etc/shadow /etc/group)"
for bad_name in 'a.*' '.*' 'a:b' 'a b' 'x/y' 'user$name' 'r.*t' '`id`' '$(id)'; do
    if "$U" adduser "$bad_name" >/dev/null 2>&1; then
        bad "adduser refused '$bad_name'"
    else
        ok "adduser refused '$bad_name'"
    fi
done
_AFTER="$(cat /etc/passwd /etc/shadow /etc/group)"
[ "$_BEFORE" = "$_AFTER" ] && ok "credential files unchanged by injection attempts" || bad "credential files were modified by rejected input"

# --- a real account lifecycle ---
if "$U" adduser testuser --uid 2001 >/dev/null 2>&1; then
    ok "adduser testuser"
    grep -q '^testuser:x:2001:2001:' /etc/passwd && ok "passwd entry correct" || bad "passwd entry wrong: $(grep '^testuser:' /etc/passwd)"
    grep -q '^testuser:\*:19000:' /etc/shadow && ok "shadow entry correct" || bad "shadow entry wrong: $(grep '^testuser' /etc/shadow)"
    # The shipped /etc/shadow has no trailing newline; a naive append glues
    # the new row onto "nobody" and silently corrupts the database.
    awk -F: 'NF!=9 {bad=1} END{exit bad+0}' /etc/shadow && ok "every shadow row has 9 fields" || bad "shadow row corrupted: $(awk -F: 'NF!=9 {print $1"="NF}' /etc/shadow | tr '\n' ' ')"
    grep -q '^nobody:\*:19000:' /etc/shadow && ok "pre-existing nobody row intact" || bad "nobody row corrupted: $(grep '^nobody' /etc/shadow)"
    grep -q '^testuser:x:2001:' /etc/group && ok "dedicated group created" || bad "group not created"
    [ -d /home/testuser ] && ok "home directory created" || bad "home directory missing"
    _HM="$(stat -c '%a' /etc/shadow 2>/dev/null || echo '?')"
    # Others digit must be 0: 640/600/440 etc pass, 644/646/444 fail.
    # A first-digit heuristic (6??) would wrongly accept 644 as safe.
    case "$_HM" in
      [0-7][0-7][0-7])
        if [ "$((8#$_HM & 0004))" -eq 0 ]; then ok "shadow mode $_HM not world-readable";
        else bad "shadow mode $_HM is world-readable"; fi ;;
      *) bad "shadow mode $_HM" ;;
    esac
else
    bad "adduser testuser failed"
fi

# duplicate rejection must not corrupt the file
"$U" adduser testuser >/dev/null 2>&1 && bad "duplicate adduser rejected" || ok "duplicate adduser rejected"
"$U" adduser uidclash --uid 2001 >/dev/null 2>&1 && bad "duplicate uid rejected" || ok "duplicate uid rejected"
grep -q '^testuser:x:2001:' /etc/passwd && ok "existing account intact after rejection" || bad "existing account lost"

# --- password: salted, tagged, never a bare digest ---
printf 'guestpass123\n' | "$U" passwd testuser --stdin >/dev/null 2>&1 && ok "passwd set" || bad "passwd set failed"
_PW="$(awk -F: '$1=="testuser" { print $2; exit }' /etc/shadow)"
case "$_PW" in
  '$aira1$'*) ok "password stored in tagged salted format" ;;
  *) bad "password format: $_PW" ;;
esac
case "$_PW" in *'$'*) ok "hash carries salt/params" ;; *) bad "hash missing salt" ;; esac
printf 'guestpass123\n' | "$U" passwd aira --stdin >/dev/null 2>&1
_PW2="$(awk -F: '$1=="aira" { print $2; exit }' /etc/shadow)"
[ -n "$_PW2" ] && [ "$_PW" != "$_PW2" ] && ok "same password -> different hash (salted)" || bad "same password -> same hash (not salted)"
printf 'x\n' | "$U" passwd testuser --stdin >/dev/null 2>&1 && bad "short password refused" || ok "short password refused"
awk -F: '$1=="testuser" { exit ($2 ~ /^\$aira1\$/ ? 0 : 1) }' /etc/shadow && ok "refused password did not corrupt hash" || bad "hash corrupted by refused attempt"

# --- usermod / lock / unlock ---
"$U" usermod testuser --uid 2002 >/dev/null 2>&1 && ok "usermod uid" || bad "usermod uid"
grep -q '^testuser:x:2002:' /etc/passwd && ok "uid updated" || bad "uid not updated"
"$U" usermod testuser --lock >/dev/null 2>&1
awk -F: '$1=="testuser" { exit ($2=="!" ? 0 : 1) }' /etc/shadow && ok "lock works" || bad "lock failed"
"$U" usermod testuser --unlock >/dev/null 2>&1
awk -F: '$1=="testuser" { exit ($2=="*" ? 0 : 1) }' /etc/shadow && ok "unlock works" || bad "unlock failed"
# root must be untouched by a usermod of another user
grep -q '^root:x:0:0:' /etc/passwd && ok "root unaffected by usermod" || bad "root entry changed"

# --- groups ---
"$U" addgroup devgroup >/dev/null 2>&1 && ok "addgroup" || bad "addgroup"
"$U" groups testuser >/dev/null 2>&1 && ok "groups testuser" || bad "groups testuser"
"$U" delgroup devgroup >/dev/null 2>&1 && ok "delgroup" || bad "delgroup"
grep -q '^devgroup:' /etc/group && bad "devgroup removed" || ok "devgroup removed"
"$U" delgroup testuser >/dev/null 2>&1 && bad "primary group protected" || ok "primary group protected"
grep -q '^testuser:' /etc/group && ok "primary group intact" || bad "primary group deleted!"

# --- a locked / passwordless account must not be able to log in ---
"$U" usermod testuser --lock >/dev/null 2>&1
case "$(timeout 10 "$U" login testuser 2>&1 </dev/null)" in
  *locked*) ok "locked account cannot log in" ;;
  *) bad "locked account login not refused" ;;
esac
"$U" usermod testuser --unlock >/dev/null 2>&1
# After --unlock the marker is "*" (no password), so login must still be
# refused, but with the "no password" message rather than "locked".
case "$(timeout 10 "$U" login testuser 2>&1 </dev/null)" in
  *"no password"*) ok "unlocked-but-passwordless account cannot log in" ;;
  *) bad "unlocked-but-passwordless account login not refused" ;;
esac

# --- removal, and proof the original database is restorable ---
"$U" deluser testuser --remove-home >/dev/null 2>&1 && ok "deluser" || bad "deluser"
grep -q '^testuser:' /etc/passwd && bad "testuser still in passwd" || ok "testuser removed"
grep -q '^testuser:' /etc/shadow && bad "testuser still in shadow" || ok "testuser shadow removed"
[ -d /home/testuser ] && bad "home still present" || ok "home removed"
[ -e /etc/passwd ] && ok "passwd file survives" || bad "passwd file deleted"

restore
grep -q '^aira:' /etc/passwd && ok "restore works (aira present)" || bad "restore failed"
awk -F: 'NF!=7 {bad=1} END{exit bad+0}' /etc/passwd && ok "passwd well-formed after restore" || bad "passwd corrupt after restore"

if [ "$PASS" = "1" ]; then echo "===== USERTEST PASS ====="; else echo "===== USERTEST FAIL ====="; fi
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo halt
sleep 5