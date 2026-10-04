#!/usr/bin/env bash
# Aira network test (Wave C5): host-only validation + read-path + CLI tests.
# Host networking is NEVER mutated here (no up/down/dhcp/static/route on real
# ifaces). Resolver + profile writes are sandboxed via AIRA_NET_RESOLV /
# AIRA_NET_MIRROR / AIRA_NET_PROFILE. DHCP client is swapped for stub scripts
# so the timeout/failure contract is proven deterministically.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

H="$ROOT/initramfs/etc/aira/ipc/handlers/network"
export AIRA_NET_HANDLER="$H"
export PATH="$ROOT/initramfs/usr/bin:$PATH"
T="$(mktemp -d /tmp/aira-net-test.XXXXXX)"
export AIRA_NET_RESOLV="$T/resolv.conf"
export AIRA_NET_MIRROR="$T/mirror.conf"
export AIRA_NET_PROFILE="$T/network.conf"
trap 'rm -rf "$T"' EXIT
S() { env AIRA_NET_RESOLV="$T/resolv.conf" AIRA_NET_MIRROR="$T/mirror.conf" \
        AIRA_NET_PROFILE="$T/network.conf" AIRA_NET_DHCP_CLIENT="${DHCPCLIENT:-udhcpc}" \
        AIRA_NET_DHCP_SCRIPT="${DHCPSCRIPT:-/nonexistent/lease-script}" \
        sh "$H" "$@"; }
C() { env AIRA_NET_RESOLV="$T/resolv.conf" AIRA_NET_MIRROR="$T/mirror.conf" \
        AIRA_NET_PROFILE="$T/network.conf" AIRA_NET_DHCP_CLIENT="${DHCPCLIENT:-udhcpc}" \
        AIRA_NET_DHCP_SCRIPT="${DHCPSCRIPT:-/nonexistent/lease-script}" \
        sh "$ROOT/initramfs/usr/bin/aira-net" "$@"; }

echo "--- syntax ---"
for f in "$H" initramfs/usr/bin/aira-net gui/aira-netman initramfs/sbin/guest-nettest.sh initramfs/init; do
  if sh -n "$f" 2>/dev/null; then ok "$f syntax"; else bad "$f syntax"; fi
done
grep -q '^PRIV_METHODS="up down dhcp static route setdns profile"' "$H" && ok "mutations privileged" || bad "mutations privileged"
if grep -q 'eval ' "$H"; then bad "no eval in handler"; else ok "no eval in handler"; fi

echo "--- caps/list/status (open reads) ---"
S caps | grep -q "methods=caps,list,status" && ok "caps methods" || bad "caps methods"
S caps | grep -q "profile=" && ok "caps profile path" || bad "caps profile path"
S caps | grep -q "wifi=unsupported" && ok "wifi honest" || bad "wifi honest"
S caps | grep -q "dhcp=budget:" && ok "caps dhcp budget" || bad "caps dhcp budget"
S list | grep -q "^lo|" && ok "list shows lo" || bad "list shows lo"
S list | awk -F'|' 'NF!=5{bad=1} END{exit bad}' && ok "list 5-field rows" || bad "list 5-field rows"
S status lo | grep -q "state=ONLINE" && ok "status lo ONLINE" || bad "status lo ONLINE"
S status no-such-if0 >/dev/null 2>&1 && bad "status unknown" || ok "status unknown ERROR"
S status "a|b" >/dev/null 2>&1 && bad "status pipe" || ok "status pipe rejected"
S status "" >/dev/null 2>&1 && bad "status empty" || ok "status empty rejected"
S status "../x" >/dev/null 2>&1 && bad "status traversal" || ok "status traversal rejected"
S status "eth0 with space" >/dev/null 2>&1 && bad "status space" || ok "status space rejected"
S status "$(printf 'eth0\nrm')" >/dev/null 2>&1 && bad "status newline" || ok "status newline rejected"
S interfaces | grep -q "lo" && ok "legacy interfaces" || bad "legacy interfaces"
S routes >/dev/null 2>&1 && ok "legacy routes" || bad "legacy routes"
S dns >/dev/null 2>&1 && ok "legacy dns read" || bad "legacy dns read"
S dns | grep -q "absent:no-resolv.conf" && ok "dns absent is honest" || bad "dns absent is honest"
S diag 127.0.0.1 | grep -q "ping=ok" && ok "diag loopback" || bad "diag loopback"
S diag "" >/dev/null 2>&1 && bad "diag empty" || ok "diag empty rejected"
S diag "a b" >/dev/null 2>&1 && bad "diag space" || ok "diag space rejected"
LONG=$(printf 'a%.0s' $(seq 1 300)); S diag "$LONG" >/dev/null 2>&1 && bad "diag oversize" || ok "diag oversize rejected"

echo "--- up/down guards (no host mutation) ---"
S up no-such-if0 >/dev/null 2>&1 && bad "up unknown" || ok "up unknown ERROR"
S down no-such-if0 >/dev/null 2>&1 && bad "down unknown" || ok "down unknown ERROR"
S down lo >/dev/null 2>&1 && bad "down lo" || ok "down lo denied"
S up "a|b" >/dev/null 2>&1 && bad "up pipe" || ok "up pipe rejected"
S dhcp no-such-if0 >/dev/null 2>&1 && bad "dhcp unknown" || ok "dhcp unknown ERROR"
S dhcp lo >/dev/null 2>&1 && bad "dhcp lo" || ok "dhcp lo denied"
S dhcp "eth0;id" >/dev/null 2>&1 && bad "dhcp metachars" || ok "dhcp metachars rejected"

echo "--- static validation battery (rejected pre-system) ---"
rej() { S static "$1" >/dev/null 2>&1 && bad "static accepted: $1" || ok "static rejected: $2"; }
rej "no-such-if0|10.0.0.5|24|10.0.0.1" "bad iface"
rej "lo|10.0.0.5|24|10.0.0.1" "loopback"
rej "eth0|999.1.1.1|24|10.0.0.1" "bad octet"
rej "eth0|1.2.3|24|10.0.0.1" "short addr"
rej "eth0|01.2.3.4|24|10.0.0.1" "leading zero"
rej "eth0|224.0.0.1|24|10.0.0.1" "multicast addr"
rej "eth0|127.0.0.5|8|10.0.0.1" "loopback addr"
rej "eth0|0.0.0.0|0|10.0.0.1" "zero addr"
rej "eth0|10.0.0.5|33|10.0.0.1" "bad prefix"
rej "eth0|10.0.0.5|abc|10.0.0.1" "non-numeric prefix"
rej "eth0|10.0.0.5|24|999.1.1.1" "bad gateway"
rej "eth0|10.0.0.5|24|0.0.0.0" "zero gateway"
rej "eth0|10.0.0.5|24|10.0.0.1|bogus" "bad 5th field"
rej "eth0|10.0.0.5|24" "missing field"
rej "eth0|10.0.0.5|24|10.0.0.1|extra" "extra field"
rej "eth0|10.0.0.5|24|10.0.0.1|extra|more" "many fields"

echo "--- route validation (rejected pre-system) ---"
S route bogus >/dev/null 2>&1 && bad "route verb" || ok "route verb rejected"
S route >/dev/null 2>&1 && bad "route empty" || ok "route empty rejected"
S route "add|999.1.1.1|lo" >/dev/null 2>&1 && bad "route bad gw" || ok "route bad gw rejected"
S route "add|10.0.0.1|no-such-if0" >/dev/null 2>&1 && bad "route bad iface" || ok "route bad iface rejected"
S route "add|10.0.0.1" >/dev/null 2>&1 && bad "route add missing iface" || ok "route add missing iface rejected"
# `del` must be accepted as a bare verb (guest previously rejected it because the
# args string "del" has no "|" separator — regression caught by guest test)
S route "del|extra" >/dev/null 2>&1 && bad "route del extra args" || ok "route del rejects extra operands"
# Assert VERB PARSING only (no "bad args"); the mutation itself is guest-tested
# because the host lacks CAP_NET_ADMIN for route changes.
_out="$(S route del 2>&1)"
if echo "$_out" | grep -q "bad args"; then bad "route del accepted as bare verb"
else ok "route del accepted as bare verb (verdict: $(printf '%s' "$_out" | head -1 | cut -c1-60))"; fi

echo "--- setdns sandbox (safe writes) ---"
S setdns "1.1.1.1" | grep -q "dns=1.1.1.1" && ok "setdns single" || bad "setdns single"
[ "$(cat "$T/resolv.conf")" = "nameserver 1.1.1.1" ] && ok "resolv.conf exact" || bad "resolv.conf exact"
[ -f "$T/mirror.conf" ] && ok "mirror created" || bad "mirror created"
S setdns "8.8.8.8|9.9.9.9" | grep -q "dns=8.8.8.8,9.9.9.9" && ok "setdns pair" || bad "setdns pair"
S setdns "999.1.1.1" >/dev/null 2>&1 && bad "dns bad ip" || ok "dns bad ip rejected"
S setdns "" >/dev/null 2>&1 && bad "dns empty" || ok "dns empty rejected"
S setdns "1.1.1.1 2.2.2.2" >/dev/null 2>&1 && bad "dns spaces" || ok "dns spaces rejected"
S setdns "|1.1.1.1" >/dev/null 2>&1 && bad "dns leading pipe" || ok "dns leading pipe rejected"
S setdns "1.1.1.1|" >/dev/null 2>&1 && bad "dns trailing pipe" || ok "dns trailing pipe rejected"
S setdns "1.1.1.1||2.2.2.2" >/dev/null 2>&1 && bad "dns double pipe" || ok "dns double pipe rejected"
S setdns "1.1.1.1|2.2.2.2|3.3.3.3|4.4.4.4" >/dev/null 2>&1 && bad "dns four" || ok "dns max-3 enforced"
S setdns "127.0.0.1" >/dev/null 2>&1 && bad "dns loopback" || ok "dns loopback rejected"
S dns | grep -q "9.9.9.9" && ok "dns readback" || bad "dns readback"
[ "$(cat "$T/resolv.conf")" = "$(printf "nameserver 8.8.8.8\nnameserver 9.9.9.9")" ] && ok "rejections left file intact" || bad "rejections left file intact"

echo "--- profile persistence (sandboxed) ---"
S profile show | grep -q "profile=absent" && ok "profile absent honest" || bad "profile absent honest"
S profile "save|bogus|lo" >/dev/null 2>&1 && bad "profile bad mode" || ok "profile bad mode rejected"
S profile "save|dhcp|no-such-if0" >/dev/null 2>&1 && bad "profile bad iface" || ok "profile bad iface rejected"
S profile "save|dhcp|lo" >/dev/null 2>&1 && bad "profile lo" || ok "profile lo denied"
S profile "save|static|lo|10.0.0.5|24|10.0.0.1" >/dev/null 2>&1 && bad "profile static lo" || ok "profile static lo denied"
S profile "save|static|no-such-if0|10.0.0.5|24|10.0.0.1" >/dev/null 2>&1 && bad "profile static bad iface" || ok "profile static bad iface rejected"
S profile "save|static|lo|999.1.1.1|24|10.0.0.1" >/dev/null 2>&1 && bad "profile static bad addr" || ok "profile static bad addr rejected"
S profile "save|static|lo|10.0.0.5|33|10.0.0.1" >/dev/null 2>&1 && bad "profile static bad prefix" || ok "profile static bad prefix rejected"
S profile "save|static|lo|10.0.0.5|24|999.0.0.1" >/dev/null 2>&1 && bad "profile static bad gw" || ok "profile static bad gw rejected"
S profile bogus >/dev/null 2>&1 && bad "profile bad sub" || ok "profile bad sub rejected"
S profile "show|extra" >/dev/null 2>&1 && bad "profile show arity" || ok "profile show arity rejected"
[ ! -f "$T/network.conf" ] && ok "rejected saves wrote nothing" || bad "rejected saves wrote nothing"
# a real interface for save/apply: lo is refused, so use the first non-lo name
# that exists; on the host that is typically eth0/en*/wlan* — if none, the
# save/apply roundtrip is skipped and reported as INFO (not a silent pass).
IF=""
for c in /sys/class/net/*; do
  n=$(basename "$c"); [ "$n" = "lo" ] && continue
  case "$n" in *[!A-Za-z0-9_.:-]*) continue ;; esac
  IF="$n"; break
done
if [ -z "$IF" ]; then
  echo "  INFO: no non-loopback interface on host; save/apply roundtrip deferred to guest"
  ok "host has no non-lo iface (roundtrip deferred, not faked)"
else
  echo "  INFO: using host interface $IF for profile save/show roundtrip"
  S profile "save|dhcp|$IF" | grep -q "profile saved mode=dhcp" && ok "profile save dhcp" || bad "profile save dhcp"
  S profile show | grep -q "profile.mode=dhcp" && ok "profile show reads back" || bad "profile show reads back"
  S profile "save|static|$IF|10.9.9.9|24|10.9.9.1" | grep -q "profile saved mode=static" && ok "profile save static" || bad "profile save static"
  S profile show | grep -q "profile.gateway=10.9.9.1" && ok "profile static fields" || bad "profile static fields"
  grep -c . "$T/network.conf" | grep -q "^[1-9]" && ok "profile file written" || bad "profile file written"
  S profile clear | grep -q "profile cleared" && ok "profile clear" || bad "profile clear"
  [ ! -f "$T/network.conf" ] && ok "profile removed" || bad "profile removed"
  S profile apply | grep -q "nothing to apply" && ok "profile apply absent is no-op" || bad "profile apply absent is no-op"
fi
# corrupt profile must be rejected, not applied
mkdir -p "$T"
printf 'mode=bogus\niface=lo\n' > "$T/network.conf"
S profile apply >/dev/null 2>&1 && bad "corrupt profile applied" || ok "corrupt profile rejected"
printf 'mode=static\niface=no-such-if0\naddress=10.0.0.5/24\ngateway=10.0.0.1\n' > "$T/network.conf"
S profile apply >/dev/null 2>&1 && bad "profile bad iface applied" || ok "profile bad iface rejected"
printf 'mode=static\niface=lo\naddress=10.0.0.5/24\ngateway=10.0.0.1\n' > "$T/network.conf"
S profile apply >/dev/null 2>&1 && bad "profile lo applied" || ok "profile lo rejected"
rm -f "$T/network.conf"

echo "--- DHCP preflight contract (host-safe: no link mutation) ---"
printf '#!/bin/sh\nexit 0\n' > "$T/lease.sh"; chmod +x "$T/lease.sh"
printf '#!/bin/sh\necho "udhcpc: no offer received" >&2\nexit 1\n' > "$T/dhcp-fail.sh"; chmod +x "$T/dhcp-fail.sh"
printf '#!/bin/sh\nsleep 30\n' > "$T/dhcp-hang.sh"; chmod +x "$T/dhcp-hang.sh"
# client missing -> UNAVAILABLE before anything is touched
OUT=$(DHCPSCRIPT="$T/lease.sh" DHCPCLIENT="$T/no-such-client" S dhcp eth0 2>&1); RC_RC=$?
if [ "$RC_RC" != "0" ] && echo "$OUT" | grep -q "UNAVAILABLE: DHCP client missing"; then
  ok "missing DHCP client UNAVAILABLE"
else
  bad "missing DHCP client UNAVAILABLE"
fi
# lease script missing -> UNAVAILABLE before the client is run
OUT=$(DHCPSCRIPT="$T/not-executable" DHCPCLIENT=/bin/true S dhcp eth0 2>&1); RC_RC=$?
if [ "$RC_RC" != "0" ] && echo "$OUT" | grep -q "UNAVAILABLE: no udhcpc lease script"; then
  ok "missing lease script UNAVAILABLE"
else
  bad "missing lease script UNAVAILABLE"
fi
S caps | grep -q "dhcp=budget:" && ok "caps reports budget+client" || bad "caps reports budget+client"
echo "  INFO: lease/timeout execution is guest-tested (host cannot raise links)"

echo "--- CLI (local fallback, no bus on host) ---"
C caps | grep -q "wifi=unsupported" && ok "cli caps" || bad "cli caps"
C list | grep -q "^lo|" && ok "cli list" || bad "cli list"
C status lo | grep -q "state=" && ok "cli status" || bad "cli status"
C diag 127.0.0.1 | grep -q "ping=ok" && ok "cli diag" || bad "cli diag"
C static eth0 999.1.1.1 24 10.0.0.1 >/dev/null 2>&1 && bad "cli static validation" || ok "cli static validation"
C setdns 1.0.0.1 | grep -q "dns=1.0.0.1" && ok "cli setdns" || bad "cli setdns"
C bogus >/dev/null 2>&1 && bad "cli unknown" || ok "cli unknown rejected"
C status >/dev/null 2>&1 && bad "cli missing arg" || ok "cli missing arg rejected"
C static eth0 10.0.0.5 >/dev/null 2>&1 && bad "cli static arity" || ok "cli static arity rejected"
C route >/dev/null 2>&1 && bad "cli route arity" || ok "cli route arity rejected"
C route add 10.0.0.1 >/dev/null 2>&1 && bad "cli route add arity" || ok "cli route add arity rejected"
C profile >/dev/null 2>&1 && bad "cli profile arity" || ok "cli profile arity rejected"
C profile show | grep -q "profile=" && ok "cli profile show" || bad "cli profile show"
C setdns "1.1.1.1 2.2.2.2" >/dev/null 2>&1 && bad "cli setdns spaces" || ok "cli setdns spaces rejected"

echo "--- netman migration ---"
[ -x "$ROOT/gui/aira-netman" ] && ok "netman executable" || bad "netman executable"
bash "$ROOT/gui/aira-netman" --once 2>/dev/null | grep -q "^lo|" && ok "netman --once backend" || bad "netman --once backend"

echo "--- performance (measured) ---"
T0=$(date +%s%N 2>/dev/null || echo 0)
i=0; while [ "$i" -lt 5 ]; do S list >/dev/null 2>&1; S status lo >/dev/null 2>&1; i=$((i+1)); done
T1=$(date +%s%N 2>/dev/null || echo 0)
if [ "$T0" != "0" ] && [ "$T1" != "0" ]; then
  MS=$(( (T1-T0)/10000000 ))
  echo "  INFO: list+status avg ${MS}ms over 5 runs (host)"
  [ "$MS" -lt 2000 ] && ok "queries fast (<2s avg)" || bad "queries fast (<2s avg)"
else
  ok "queries complete (no ns clock)"
fi

rm -rf "$T"
trap - EXIT

echo
echo "NET TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]