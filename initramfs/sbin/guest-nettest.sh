#!/bin/sh
# In-guest network verification (runs as init when aira_nettest=1).
# Requires virtual networking (boot --net user): proves discovery, DHCP
# lease, state honesty, static idempotency, route/DNS cycles, link cycles,
# privilege denial, and malformed-request rejection. Restores ONLINE at end.
# Prints NETTEST markers to serial, then poweroff. Never hangs.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export TERM=linux
PASS=1
echo "===== NETTEST START ====="
command -v aira-net >/dev/null 2>&1 && echo "NETTEST OK: aira-net present" || { echo "NETTEST FAIL: aira-net missing"; PASS=0; }
[ -x /etc/aira/ipc/handlers/network ] && echo "NETTEST OK: network handler present" || { echo "NETTEST FAIL: network handler missing"; PASS=0; }
command -v udhcpc >/dev/null 2>&1 && echo "NETTEST OK: udhcpc present" || { echo "NETTEST FAIL: udhcpc missing"; PASS=0; }
command -v ip >/dev/null 2>&1 && echo "NETTEST OK: ip present" || { echo "NETTEST FAIL: ip missing"; PASS=0; }
if command -v aira-ipc >/dev/null 2>&1 && aira-ipc ping >/dev/null 2>&1; then
    echo "NETTEST INFO: bus reachable"; _BUS=1
else
    echo "NETTEST FAIL: bus unreachable (need bus for priv-path tests)"; PASS=0; _BUS=0
fi
_IF=""
for _c in /sys/class/net/*; do
    _n="$(basename "$_c")"
    [ "$_n" = "lo" ] && continue
    case "$_n" in *[!A-Za-z0-9_.:-]*) continue ;; esac
    _IF="$_n"
    break
done
if [ -z "$_IF" ]; then
    echo "NETTEST FAIL: no non-loopback interface (boot with --net user)"; PASS=0
else
    echo "NETTEST INFO: test interface $_IF"
fi
aira-net caps 2>/dev/null | grep -q "wifi=unsupported" && echo "NETTEST OK: wifi honestly unsupported" || { echo "NETTEST FAIL: wifi honesty"; PASS=0; }
aira-net list 2>/dev/null | grep -q "^$_IF|" && echo "NETTEST OK: list discovers $_IF" || { echo "NETTEST FAIL: list discovery"; PASS=0; }
aira-ipc call network interfaces >/dev/null 2>&1 && echo "NETTEST OK: legacy interfaces compat" || { echo "NETTEST FAIL: legacy compat"; PASS=0; }
echo "--- DHCP lease (the core proof) ---"
if [ -n "$_IF" ]; then
    _PRE="$(aira-net status "$_IF" 2>/dev/null || true)"
    echo "NETTEST INFO: pre-state: $_PRE"
    if aira-net dhcp "$_IF" > /tmp/nettest-dhcp.out 2>&1; then
        echo "NETTEST OK: dhcp reported success"
        cat /tmp/nettest-dhcp.out
    else
        echo "NETTEST FAIL: dhcp failed"; cat /tmp/nettest-dhcp.out 2>/dev/null; PASS=0
    fi
    _ST="$(aira-net status "$_IF" 2>/dev/null || true)"
    echo "NETTEST INFO: post-dhcp: $_ST"
    case "$_ST" in *state=ONLINE*) echo "NETTEST OK: observed ONLINE (addr+route, not assumed)" ;; *)
        echo "NETTEST FAIL: not ONLINE after lease"; PASS=0 ;; esac
    _LA="$(printf "%s" "$_ST" | sed 's/.*addrs=\([^ ]*\).*/\1/')"
    _GW="$(ip -o -4 route show default 2>/dev/null | awk '{print $3}' | head -n 1)"
    _LEASE_ADDR="${_LA%%/*}"; _LEASE_PFX="${_LA##*/}"; _LEASE_PFX="${_LEASE_PFX%%,*}"
    echo "NETTEST INFO: lease addr=$_LEASE_ADDR pfx=$_LEASE_PFX gw=$_GW"
    echo "--- gateway connectivity ---"
    if [ -n "$_GW" ] && aira-net diag "$_GW" 2>/dev/null | grep -q "ping=ok"; then
        echo "NETTEST OK: gateway ping via diag"
    else
        echo "NETTEST FAIL: gateway unreachable"; PASS=0
    fi
    echo "--- DNS from lease ---"
    if grep -q "^nameserver" /etc/resolv.conf 2>/dev/null; then
        echo "NETTEST OK: resolv.conf populated: $(grep "^nameserver" /etc/resolv.conf 2>/dev/null | tr '\n' ' ')"
    else
        echo "NETTEST FAIL: no nameserver after lease"; PASS=0
    fi
    aira-net diag 8.8.8.8 > /tmp/nettest-ext.out 2>&1 || true
    echo "NETTEST INFO: external: $(cat /tmp/nettest-ext.out 2>/dev/null)"
    echo "--- static idempotency (re-apply lease values) ---"
    if [ -n "$_LEASE_ADDR" ] && [ -n "$_GW" ]; then
        if aira-net static "$_IF" "$_LEASE_ADDR" "$_LEASE_PFX" "$_GW" 2>/dev/null | grep -q "already-configured"; then
            echo "NETTEST OK: static idempotent on current lease"
        else
            echo "NETTEST FAIL: static idempotency"; PASS=0
        fi
    else
        echo "NETTEST FAIL: no lease values for idempotency check"; PASS=0
    fi
    echo "--- invalid static rejected, state preserved ---"
    _BEFORE="$(aira-net status "$_IF" 2>/dev/null | sed 's/.*state=\([A-Z_]*\).*/\1/')"
    for _bad in "$_IF|999.1.1.1|24|$_GW" "$_IF|$_LEASE_ADDR|33|$_GW" "$_IF|$_LEASE_ADDR|24|999.0.0.1"; do
        if aira-ipc call network static "$_bad" >/dev/null 2>&1; then
            echo "NETTEST FAIL: invalid static accepted: $_bad"; PASS=0
        fi
    done
    echo "NETTEST OK: invalid statics rejected"
    _AFTER="$(aira-net status "$_IF" 2>/dev/null | sed 's/.*state=\([A-Z_]*\).*/\1/')"
    if [ "$_BEFORE" = "$_AFTER" ]; then echo "NETTEST OK: state unchanged ($_AFTER)";
    else echo "NETTEST FAIL: state moved $_BEFORE -> $_AFTER"; PASS=0; fi
    echo "--- route cycle ---"
    # Precondition: the gateway must be REACHABLE for a default route to be
    # installable. The kernel enforces this (RTNETLINK "Network is
    # unreachable") when the connected subnet route is missing. Ensure the
    # lease is intact first, and fail loudly if it is not.
    if ! ip -o -4 addr show dev "$_IF" 2>/dev/null | grep -q "scope global"; then
        aira-net dhcp "$_IF" >/dev/null 2>&1 || true
    fi
    _SUBNET_OK=no
    ip route show 2>/dev/null | grep -q "dev $_IF" && _SUBNET_OK=yes
    echo "NETTEST INFO: connected route present: $_SUBNET_OK"
    if [ "$_SUBNET_OK" = "yes" ]; then
        echo "NETTEST OK: subnet route present (gateway is reachable)"
    else
        echo "NETTEST FAIL: no connected route for $_IF — gateway unreachable"; PASS=0
    fi
    _RL_BEFORE="$(ip -o -4 route show default 2>/dev/null)"
    echo "NETTEST DIAG: raw default route before del:"; printf '%s\n' "$_RL_BEFORE" | sed 's/^/NETTEST DIAG:   /'
    _DELD=0
    if aira-net route del > /tmp/nettest-routedel.out 2>&1; then
        echo "NETTEST OK: default route deleted"; _DELD=1
        sed 's/^/NETTEST DIAG:   /' /tmp/nettest-routedel.out 2>/dev/null
    else
        echo "NETTEST FAIL: route del rejected a present default route"
        sed 's/^/NETTEST DIAG:   /' /tmp/nettest-routedel.out 2>/dev/null
        echo "NETTEST DIAG: flush attempt:"; ip route flush default 2>&1 | sed 's/^/NETTEST DIAG:   /'
        echo "NETTEST DIAG: after flush:"; ip -o -4 route show default 2>/dev/null | sed 's/^/NETTEST DIAG:   /'
        PASS=0
    fi
    if [ "$_DELD" = "1" ]; then
        _NORT="$(aira-net status "$_IF" 2>/dev/null || true)"
        case "$_NORT" in *state=ONLINE*) echo "NETTEST FAIL: ONLINE without route"; PASS=0 ;;
        *) echo "NETTEST OK: honesty without route: $(printf "%s" "$_NORT" | sed 's/.*state=\([A-Z_]*\).*/\1/')" ;; esac
    fi
    if [ -n "$_GW" ] && [ "$_SUBNET_OK" = "yes" ] && aira-net route add "$_GW" "$_IF" > /tmp/nettest-routeadd.out 2>&1; then
        echo "NETTEST OK: default route restored"
        sed 's/^/NETTEST DIAG:   /' /tmp/nettest-routeadd.out 2>/dev/null
    else
        echo "NETTEST FAIL: route restore"
        if [ -z "$_GW" ]; then echo "NETTEST DIAG: no gateway parsed from lease"; PASS=0; fi
        if [ "$_SUBNET_OK" != "yes" ]; then echo "NETTEST DIAG: gateway unreachable (kernel refuses default route)"; fi
        sed 's/^/NETTEST DIAG:   /' /tmp/nettest-routeadd.out 2>/dev/null
        echo "NETTEST DIAG: gw=[$_GW]"
        echo "NETTEST DIAG: addrs:"; ip -o -4 addr show dev "$_IF" 2>/dev/null | sed 's/^/NETTEST DIAG:   /'
        echo "NETTEST DIAG: FULL route table:"; ip route show 2>/dev/null | sed 's/^/NETTEST DIAG:   /'
        echo "NETTEST DIAG: link state:"; cat "/sys/class/net/$_IF/operstate" 2>/dev/null | sed 's/^/NETTEST DIAG:   /'
        PASS=0
    fi
    echo "--- DNS cycle ---"
    if aira-net setdns 1.1.1.1 >/dev/null 2>&1 && grep -q "^nameserver 1.1.1.1" /etc/resolv.conf 2>/dev/null; then
        echo "NETTEST OK: setdns applied"
    else
        echo "NETTEST FAIL: setdns"; PASS=0
    fi
    if mount 2>/dev/null | grep -q " /persist " && grep -q "^nameserver 1.1.1.1" /persist/etc/resolv.conf 2>/dev/null; then
        echo "NETTEST OK: dns mirror under /persist"
    elif mount 2>/dev/null | grep -q " /persist "; then
        echo "NETTEST FAIL: dns mirror missing"; PASS=0
    else
        echo "NETTEST INFO: no /persist (mirror unchecked)"
    fi
    aira-net dhcp "$_IF" >/dev/null 2>&1 || true
    grep -q "^nameserver" /etc/resolv.conf 2>/dev/null && echo "NETTEST OK: lease DNS restored file" || { echo "NETTEST FAIL: dns restore"; PASS=0; }
    echo "--- link cycle ---"
    if aira-net down "$_IF" >/dev/null 2>&1; then
        _DS="$(aira-net status "$_IF" 2>/dev/null | sed 's/.*state=\([A-Z_]*\).*/\1/')"
        [ "$_DS" = "DOWN" ] && echo "NETTEST OK: link down observed" || { echo "NETTEST FAIL: down state $_DS"; PASS=0; }
    else
        echo "NETTEST FAIL: down failed"; PASS=0
    fi
    if aira-net up "$_IF" >/dev/null 2>&1; then
        _US="$(aira-net status "$_IF" 2>/dev/null | sed 's/.*state=\([A-Z_]*\).*/\1/')"
        [ "$_US" != "DOWN" ] && [ "$_US" != "ERROR" ] && echo "NETTEST OK: link up ($_US)" || { echo "NETTEST FAIL: up state $_US"; PASS=0; }
    else
        echo "NETTEST FAIL: up failed"; PASS=0
    fi
    aira-net dhcp "$_IF" >/dev/null 2>&1 || true
    echo "--- privilege denial (unprivileged callers) ---"
    if su aira -c "aira-net dhcp $_IF" >/dev/null 2>&1; then echo "NETTEST FAIL: unpriv dhcp allowed"; PASS=0;
    else echo "NETTEST OK: unprivileged dhcp denied"; fi
    if su aira -c "aira-net down $_IF" >/dev/null 2>&1; then echo "NETTEST FAIL: unpriv down allowed"; PASS=0;
    else echo "NETTEST OK: unprivileged down denied"; fi
    if su aira -c "aira-net setdns 9.9.9.9" >/dev/null 2>&1; then echo "NETTEST FAIL: unpriv setdns allowed"; PASS=0;
    else echo "NETTEST OK: unprivileged setdns denied"; fi
    echo "--- privilege probing (vacuous vs real denial) ---"
    if su aira -c 'id' 2>&1 | grep -q "uid=1000"; then
        echo "NETTEST OK: su aira executes"
    else
        echo "NETTEST FAIL: su aira broken"; PASS=0
    fi
    # Positive control: an unprivileged user MUST be able to reach the bus and
    # perform open reads. Without this, "denied" below proves nothing.
    su -s /bin/sh aira -c 'id; echo PATH=$PATH; command -v aira-ipc; command -v nc; command -v timeout' \
        > /tmp/nettest-aira-env.out 2>&1
    echo "NETTEST DIAG: as-aira env:"; sed 's/^/NETTEST DIAG:   /' /tmp/nettest-aira-env.out 2>/dev/null
    su -s /bin/sh aira -c 'nc -w 4 127.0.0.1 41234 </dev/null; echo nc_rc=$?' \
        > /tmp/nettest-aira-nc.out 2>&1
    echo "NETTEST DIAG: as-aira raw nc:"; sed 's/^/NETTEST DIAG:   /' /tmp/nettest-aira-nc.out 2>/dev/null
    su -s /bin/sh aira -c 'aira-ipc ping hello-aira; echo cli_rc=$?' \
        > /tmp/nettest-aira-ping.out 2>&1
    echo "NETTEST DIAG: as-aira cli ping:"; sed 's/^/NETTEST DIAG:   /' /tmp/nettest-aira-ping.out 2>/dev/null
    if grep -q "pong" /tmp/nettest-aira-ping.out 2>/dev/null; then
        echo "NETTEST OK: bus reachable as aira (denials below are real)"
    else
        echo "NETTEST FAIL: bus unreachable as aira (privilege denials unproven)"; PASS=0
    fi
    su -s /bin/sh aira -c "aira-net list" > /tmp/nettest-aira-list.out 2>&1
    if grep -q "^$_IF|" /tmp/nettest-aira-list.out 2>/dev/null; then
        echo "NETTEST OK: unprivileged reads open"
    else
        echo "NETTEST FAIL: unprivileged reads blocked"; cat /tmp/nettest-aira-list.out 2>/dev/null; PASS=0
    fi
    # Local (bus-bypassing) path must also be denied for a non-root uid.
    if su -s /bin/sh aira -c "/etc/aira/ipc/handlers/network down $_IF" >/tmp/nettest-aira-local.out 2>&1; then
        echo "NETTEST FAIL: local handler path allowed non-root mutation"; PASS=0
    else
        echo "NETTEST OK: local handler path denies non-root mutation"
    fi
    echo "--- malformed over the wire ---"
    _R="$(printf "AIRA1|tn1|0:nobody|network|static|none|%s\n" "$_IF" 2>/dev/null | timeout 5 nc -w 5 127.0.0.1 41234 2>/dev/null || true)"
    case "$_R" in *ERR*) echo "NETTEST OK: short static rejected" ;; *) echo "NETTEST FAIL: short static: $_R"; PASS=0 ;; esac
    _R="$(printf "AIRA1|tn2|0:nobody|network|up|none|BAD-IFACE-NAME!\n" 2>/dev/null | timeout 5 nc -w 5 127.0.0.1 41234 2>/dev/null || true)"
    case "$_R" in *ERR*) echo "NETTEST OK: bad iface rejected" ;; *) echo "NETTEST FAIL: bad iface: $_R"; PASS=0 ;; esac
    echo "--- read-path concurrency ---"
    rm -f /tmp/nettest-conc-*.out
    for _k in 1 2 3 4 5; do ( aira-net list >"/tmp/nettest-conc-$_k.out" 2>&1 ) & done
    wait
    _COK=0; for _k in 1 2 3 4 5; do grep -q "^$_IF|" "/tmp/nettest-conc-$_k.out" 2>/dev/null && _COK=$((_COK+1)); done
    if [ "$_COK" = "5" ]; then echo "NETTEST OK: 5x concurrent list";
    else echo "NETTEST FAIL: concurrent list $_COK/5"; PASS=0; fi
    echo "--- profile persistence (real /persist, survives reboot) ---"
    if aira-net profile save dhcp "$_IF" >/dev/null 2>&1 && aira-net profile show | grep -q "profile.mode=dhcp"; then
        echo "NETTEST OK: profile saved+read back"
    else
        echo "NETTEST FAIL: profile save"; PASS=0
    fi
    if [ -f /persist/etc/aira/network.conf ]; then
        echo "NETTEST OK: profile lives on /persist (persistent store)"
    else
        echo "NETTEST FAIL: profile not on /persist"; PASS=0
    fi
    if mount 2>/dev/null | grep -q " /persist "; then
        # simulate the next boot: tear the runtime config down, then re-apply
        aira-net route del >/dev/null 2>&1 || true
        ip addr flush dev "$_IF" >/dev/null 2>&1 || true
        _PRESTATE="$(aira-net status "$_IF" 2>/dev/null | sed 's/.*state=\([A-Z_]*\).*/\1/')"
        echo "NETTEST INFO: state after teardown: $_PRESTATE"
        case "$_PRESTATE" in ONLINE) echo "NETTEST FAIL: teardown did not clear state"; PASS=0 ;; esac
        if aira-net profile apply >/dev/null 2>&1; then
            _POSTSTATE="$(aira-net status "$_IF" 2>/dev/null | sed 's/.*state=\([A-Z_]*\).*/\1/')"
            if [ "$_POSTSTATE" = "ONLINE" ]; then
                echo "NETTEST OK: profile apply restored ONLINE from persisted profile"
            else
                echo "NETTEST FAIL: profile apply -> $_POSTSTATE"; PASS=0
            fi
        else
            echo "NETTEST FAIL: profile apply"; PASS=0
        fi
        # corrupt profile must be refused, not applied
        cp -f /persist/etc/aira/network.conf /tmp/nettest-profile.bak
        printf 'mode=static\niface=no-such-if0\naddress=10.0.0.5/24\ngateway=10.0.0.1\n' > /persist/etc/aira/network.conf
        if aira-net profile apply >/dev/null 2>&1; then
            echo "NETTEST FAIL: corrupt profile applied"; PASS=0
        else
            echo "NETTEST OK: corrupt profile refused"
        fi
        cp -f /tmp/nettest-profile.bak /persist/etc/aira/network.conf
        rm -f /tmp/nettest-profile.bak
    else
        echo "NETTEST INFO: no /persist; profile apply-after-reboot proven in the second boot instead"
    fi
    echo "--- restoring lease for the injected-DHCP section ---"
    # The DHCP-injection probes deliberately make success impossible (link down,
    # no address). Restore a real lease first, then tear down again locally.
    if aira-net dhcp "$_IF" >/dev/null 2>&1; then
        echo "NETTEST OK: lease re-established after route-cycle test"
    else
        echo "NETTEST INFO: lease re-establish reported failure; continuing"
    fi
    _RS="$(aira-net status "$_IF" 2>/dev/null | sed 's/.*state=\([A-Z_]*\).*/\1/')"
    echo "NETTEST INFO: state before injected-DHCP probes: $_RS"
    if [ "$_RS" = "ONLINE" ]; then echo "NETTEST OK: ONLINE before injected-DHCP probes";
    else echo "NETTEST FAIL: expected ONLINE before injected-DHCP probes (got $_RS)"; PASS=0; fi
    echo "--- DHCP failure/timeout contract (injected client) ---"
    # Run the handler DIRECTLY: the injection seams are environment variables
    # and the IPC dispatcher does not forward client environments, so these
    # must bypass the bus. Bus-path DHCP is exercised with the real udhcpc above.
    # The lease script must be executable AND actually configure the interface,
    # otherwise "success" would only mean "the stub exited 0".
    NETH=/etc/aira/ipc/handlers/network
    printf '#!/bin/sh\nexit 0\n' > /tmp/nettest-lease.sh
    printf '#!/bin/sh\necho "udhcpc: no offer received" >&2\nexit 1\n' > /tmp/nettest-dhcp-fail.sh
    printf '#!/bin/sh\nsleep 30\n' > /tmp/nettest-dhcp-hang.sh
    chmod +x /tmp/nettest-dhcp-fail.sh /tmp/nettest-dhcp-hang.sh /tmp/nettest-lease.sh
    # Break the link AND drop addressing first: a successful-looking verdict
    # must be impossible while no lease can possibly exist.
    ip link set "$_IF" down 2>/dev/null || true
    ip addr flush dev "$_IF" 2>/dev/null || true
    ip route del default 2>/dev/null || true
    if AIRA_NET_DHCP_CLIENT=/tmp/nettest-dhcp-fail.sh AIRA_NET_DHCP_SCRIPT=/tmp/nettest-lease.sh \
        sh "$NETH" dhcp "$_IF" > /tmp/nettest-dhcpfail.out 2>&1; then
        echo "NETTEST FAIL: no-lease reported success"; cat /tmp/nettest-dhcpfail.out 2>/dev/null; PASS=0
    else
        if grep -q "no lease configured" /tmp/nettest-dhcpfail.out 2>/dev/null \
           || grep -q "no usable lease" /tmp/nettest-dhcpfail.out 2>/dev/null; then
            echo "NETTEST OK: no-lease failure reported honestly"
            sed 's/^/NETTEST INFO:   /' /tmp/nettest-dhcpfail.out 2>/dev/null
        else
            echo "NETTEST FAIL: no-lease message: $(cat /tmp/nettest-dhcpfail.out 2>/dev/null)"; PASS=0
        fi
    fi
    _HS="$(date +%s 2>/dev/null || echo 0)"
    AIRA_NET_DHCP_CLIENT=/tmp/nettest-dhcp-hang.sh AIRA_NET_DHCP_SCRIPT=/tmp/nettest-lease.sh \
        sh "$NETH" dhcp "$_IF" >/dev/null 2>&1
    _HE="$(date +%s 2>/dev/null || echo 0)"
    _HD=$((_HE-_HS))
    # Note: this section runs against a torn-down link, so the honest
    # expectation for the hang case is "bounded, then reported as no-lease".
    if [ "$_HD" -ge 1 ] && [ "$_HD" -le 14 ]; then
        echo "NETTEST OK: hanging client bounded (${_HD}s, no orphan)"
        echo "NETTEST INFO: bounded verdict detail:"
        AIRA_NET_DHCP_CLIENT=/tmp/nettest-dhcp-hang.sh AIRA_NET_DHCP_SCRIPT=/tmp/nettest-lease.sh \
            sh "$NETH" dhcp "$_IF" 2>&1 | sed 's/^/NETTEST INFO:   /'
    else
        echo "NETTEST FAIL: hang bound ${_HD}s"; PASS=0
    fi
    if command -v pidof >/dev/null 2>&1; then
        _STRAY="$(pidof udhcpc 2>/dev/null)"
        [ -z "$_STRAY" ] && echo "NETTEST OK: no udhcpc strays after failure/timeout" \
            || echo "NETTEST INFO: udhcpc pids present after test: $_STRAY"
    fi
    rm -f /tmp/nettest-dhcpfail.out
    echo "--- static conflict detection ---"
    # Re-establish the lease first: the DHCP-failure section above deliberately
    # tore the link down, so there is nothing to conflict with until now.
    aira-net dhcp "$_IF" >/dev/null 2>&1 || true
    _S1="$(aira-net status "$_IF" 2>/dev/null | sed 's/.*addrs=\([^ ]*\).*/\1/')"
    echo "NETTEST INFO: addressing before static-conflict probe: ${_S1:-none}"
    if aira-net static "$_IF" "10.55.0.9" 24 "10.55.0.1" >/tmp/nettest-conflict.out 2>&1; then
        echo "NETTEST FAIL: static overwrote existing addressing silently"
        cat /tmp/nettest-conflict.out 2>/dev/null; PASS=0
    elif grep -q "conflict:" /tmp/nettest-conflict.out 2>/dev/null; then
        echo "NETTEST OK: conflicting static refused"
    else
        echo "NETTEST FAIL: static refused for the wrong reason: $(head -n 1 /tmp/nettest-conflict.out 2>/dev/null)"; PASS=0
    fi
    _S2="$(aira-net status "$_IF" 2>/dev/null | sed 's/.*addrs=\([^ ]*\).*/\1/')"
    [ "$_S1" = "$_S2" ] && echo "NETTEST OK: refused static changed nothing ($_S2)" \
        || { echo "NETTEST FAIL: addressing mutated $_S1 -> $_S2"; PASS=0; }
    if aira-net static "$_IF" "10.55.0.9" 24 "10.55.0.1" flush >/tmp/nettest-flush.out 2>&1; then
        echo "NETTEST OK: explicit flush replaces addressing"
        grep "state=" /tmp/nettest-flush.out 2>/dev/null | sed 's/^/NETTEST INFO:   /'
    else
        echo "NETTEST FAIL: flush static rejected: $(head -n 1 /tmp/nettest-flush.out 2>/dev/null)"; PASS=0
    fi
    aira-net dhcp "$_IF" >/dev/null 2>&1 || true
    rm -f /tmp/nettest-conflict.out /tmp/nettest-lease.sh /tmp/nettest-dhcp-fail.sh /tmp/nettest-dhcp-hang.sh
    echo "--- restore ONLINE + leave profile for cross-boot check ---"
    aira-net profile clear >/dev/null 2>&1 || true
    aira-net dhcp "$_IF" >/dev/null 2>&1 || true
    _FIN="$(aira-net status "$_IF" 2>/dev/null | sed 's/.*state=\([A-Z_]*\).*/\1/')"
    echo "NETTEST INFO: final state $_FIN"
    if [ "$_FIN" = "ONLINE" ]; then echo "NETTEST OK: final state ONLINE"; else echo "NETTEST FAIL: final state $_FIN"; PASS=0; fi
    if aira-net profile save dhcp "$_IF" >/dev/null 2>&1; then
        echo "NETTEST OK: dhcp profile persisted for next boot (aira_netpersist=1)"
    else
        echo "NETTEST INFO: profile persist skipped ($(aira-net profile save dhcp "$_IF" 2>&1 | head -n 1))"
    fi
    echo "--- boot log evidence ---"
    echo "NETTEST INFO: net service log:"; sed 's/^/NETTEST INFO:   /' /var/log/airaos/net.log 2>/dev/null | head -n 12
fi
if [ "$PASS" = "1" ]; then echo "===== NETTEST PASS ====="; else echo "===== NETTEST FAIL ====="; fi
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo halt
sleep 5
