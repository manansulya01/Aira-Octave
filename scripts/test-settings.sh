#!/usr/bin/env bash
# Aira settings test (Wave C2): host-only unit + attack + concurrency tests
# for the centralized store, settings IPC handler (direct exec = local path),
# aira-cfg CLI fallback (no bus on host), and managed UI smoke. No QEMU.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

H="$ROOT/initramfs/etc/aira/ipc/handlers/settings"
SCH="$ROOT/initramfs/etc/aira/settings-schema"
export AIRA_SETTINGS_HANDLER="$H"
export AIRA_SETTINGS_SCHEMA="$SCH"
export PATH="$ROOT/initramfs/usr/bin:$PATH"

echo "--- syntax + schema ---"
for f in "$H" initramfs/usr/bin/aira-cfg gui/aira-settings initramfs/sbin/guest-settingstest.sh initramfs/init; do
  if sh -n "$f" 2>/dev/null; then ok "$f syntax"; else bad "$f syntax"; fi
done
[ -f "$SCH" ] && ok "schema present" || bad "schema present"
grep -q '^PRIV_METHODS="set reset"' "$H" && ok "set/reset privileged" || bad "set/reset privileged"
if grep -q 'eval ' "$H"; then bad "no eval in handler"; else ok "no eval in handler"; fi
[ "$(grep -vc '^#\|^$' "$SCH")" = "12" ] && ok "12 schema keys" || bad "12 schema keys (got $(grep -vc '^#\|^$' "$SCH"))"

T="$(mktemp -d /tmp/aira-settings-test.XXXXXX)"
export AIRA_SETTINGS_CONF="$T/store.conf"
trap 'chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"' EXIT
S() { sh "$H" "$@"; }
C() { sh "$ROOT/initramfs/usr/bin/aira-cfg" "$@"; }

echo "--- caps/list/get (open methods) ---"
S caps | grep -q "system.hostname|string" && ok "caps hostname" || bad "caps hostname"
S caps | grep -q "UNAVAILABLE" && ok "caps honesty (host lacks hw)" || bad "caps honesty"
[ "$(S caps | wc -l)" = "12" ] && ok "caps 12 lines" || bad "caps 12 lines"
S list | grep -q "system.hostname=aira-octave" && ok "list defaults" || bad "list defaults"
S list system | grep -q "system.timezone" && ok "list namespace" || bad "list namespace"
S get system.hostname | grep -q "^system.hostname=aira-octave$" && ok "get default" || bad "get default"
S get bogus.key >/dev/null 2>&1 && bad "get unknown" || ok "get unknown rejected"

echo "--- set/reset roundtrip (store-only keys, no hw needed) ---"
S set "security.lock_timeout|600" | grep -q "=600" && ok "set lock_timeout" || bad "set lock_timeout"
[ "$(S get security.lock_timeout)" = "security.lock_timeout=600" ] && ok "get stored" || bad "get stored"
S set "network.dhcp_iface|wlan9" >/dev/null 2>&1 && ok "set dhcp_iface" || bad "set dhcp_iface"
S set "system.timezone|Europe/Berlin" >/dev/null 2>&1 && ok "set timezone" || bad "set timezone"
S reset security.lock_timeout | grep -q "=300" && ok "reset key" || bad "reset key"
S set "security.lock_timeout|111" >/dev/null 2>&1
S reset security | grep -q "reset namespace" && ok "reset namespace" || bad "reset namespace"
[ "$(S get security.lock_timeout)" = "security.lock_timeout=300" ] && ok "namespace reset effective" || bad "namespace reset effective"
S reset all | grep -q "reset all" && ok "reset all" || bad "reset all"
S validate | grep -q "^clean$" && ok "validate clean" || bad "validate clean"

echo "--- validation rejections ---"
S set "system.hostname|bad_host!!" >/dev/null 2>&1 && bad "hostname regex" || ok "hostname regex rejected"
S set "display.opacity|999" >/dev/null 2>&1 && bad "int range" || ok "int range rejected"
S set "display.opacity|abc" >/dev/null 2>&1 && bad "int type" || ok "int type rejected"
S set "appearance.theme|nope" >/dev/null 2>&1 && bad "enum" || ok "enum rejected"
S set "appearance.night|maybe" >/dev/null 2>&1 && bad "bool" || ok "bool rejected"
S set "nosuch.key|x" >/dev/null 2>&1 && bad "unknown key" || ok "unknown key rejected"
S set "system.timezone|a|b" >/dev/null 2>&1 && bad "pipe value" || ok "pipe value rejected"
S set "system.timezone" >/dev/null 2>&1 && bad "missing value" || ok "missing value rejected"
S get "system.hostname|x" >/dev/null 2>&1 && bad "get extra arg" || ok "get extra arg rejected"
S bogus >/dev/null 2>&1 && bad "unknown method" || ok "unknown method rejected"

echo "--- apply-first: failed apply stores nothing ---"
S set "appearance.theme|aira-ocean" >/dev/null 2>&1
if S get appearance.theme | grep -q "=aira-night$"; then ok "failed apply keeps default"; else bad "failed apply keeps default"; fi
S set "audio.volume|80" >/dev/null 2>&1 && bad "mixer without hw" || ok "mixer UNAVAILABLE"
S set "network.wifi|on" >/dev/null 2>&1 && bad "wifi without hw" || ok "wifi UNAVAILABLE"
S set "power.brightness|50" >/dev/null 2>&1 && bad "brightness without hw" || ok "brightness UNAVAILABLE"

echo "--- corruption handling ---"
printf 'GARBAGE-NO-EQUALS\nbogus.key=x\nsystem.hostname=way-too-long-!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n' >> "$T/store.conf"
V="$(S validate)"
case "$V" in *issues=3*) ok "corruption count (3)" ;; *) bad "corruption count (got: $V)" ;; esac
S get security.lock_timeout >/dev/null 2>&1 && ok "reads survive corruption" || bad "reads survive corruption"
S reset all >/dev/null 2>&1
[ "$(S validate)" = "clean" ] && ok "reset all cleans" || bad "reset all cleans"

echo "--- unwritable store fails honestly ---"
mkdir -p "$T/ro"
export AIRA_SETTINGS_CONF="$T/ro/store.conf"
: > "$T/ro/store.conf"
chmod 555 "$T/ro"
S set "security.lock_timeout|600" >/dev/null 2>&1 && bad "unwritable store" || ok "unwritable store rejected"
chmod 755 "$T/ro"
export AIRA_SETTINGS_CONF="$T/store.conf"

echo "--- concurrency: store never tears ---"
i=0; while [ "$i" -lt 8 ]; do ( S set "security.lock_timeout|$((100+i))" >/dev/null 2>&1 ) & i=$((i+1)); done
CBAD=0; j=0
while [ "$j" -lt 20 ]; do S validate >/dev/null 2>&1 || CBAD=1; j=$((j+1)); done
wait
[ "$CBAD" = "0" ] && ok "always parses under concurrency" || bad "always parses under concurrency"
FIN="$(S get security.lock_timeout | cut -d= -f2)"
case "$FIN" in 100|101|102|103|104|105|106|107) ok "last-writer-wins ($FIN)" ;; *) bad "final value ($FIN)" ;; esac
S reset security.lock_timeout >/dev/null 2>&1 || true

echo "--- CLI fallback (no bus on host) ---"
C caps | grep -q "system.hostname" && ok "cli caps" || bad "cli caps"
C set security.lock_timeout 700 | grep -q "=700" && ok "cli set" || bad "cli set"
C get security.lock_timeout | grep -q "=700" && ok "cli get" || bad "cli get"
C list appearance | grep -q "appearance.theme" && ok "cli list ns" || bad "cli list ns"
C validate | grep -q "clean" && ok "cli validate" || bad "cli validate"
C set audio.volume 80 >/dev/null 2>&1 && bad "cli mixer" || ok "cli mixer UNAVAILABLE"
C bogus >/dev/null 2>&1 && bad "cli unknown" || ok "cli unknown rejected"
C reset security.lock_timeout >/dev/null 2>&1 || true

echo "--- managed UI smoke ---"
[ -x "$ROOT/gui/aira-settings" ] && ok "settings executable" || bad "settings executable"
printf 'q\n' | timeout 10 bash "$ROOT/gui/aira-settings" --text 2>/dev/null | grep -q "MANAGED SETTINGS" && ok "managed section renders" || bad "managed section renders"
printf 'q\n' | timeout 10 bash "$ROOT/gui/aira-settings" --text 2>/dev/null | grep -q "UNAVAILABLE" && ok "UNAVAILABLE shown" || bad "UNAVAILABLE shown"

chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"
trap - EXIT

echo
echo "SETTINGS TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
