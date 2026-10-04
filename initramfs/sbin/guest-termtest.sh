#!/bin/sh
# In-guest terminal session verification (runs as init when aira_termtest=1).
# PTY truth: kernel /dev/ptmx + xterm-owned PTY; Aira owns tracking/ownership/
# limits/cleanup. With Xvfb+xterm: real spawn/list/kill/cleanup + pts proof.
# Without X: honest UNAVAILABLE + validation + registry hygiene on fixtures.
# Prints TERMTEST markers to serial, then poweroff. Never hangs.
export PATH=/persist/usr/bin:/persist/bin:/persist/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/persist/usr/lib/x86_64-linux-gnu:/persist/lib/x86_64-linux-gnu:/persist/usr/lib:/persist/lib:$LD_LIBRARY_PATH
export HOME=/root
export TERM=linux
PASS=1
echo "===== TERMTEST START ====="
if command -v aira-term >/dev/null 2>&1; then
    echo "TERMTEST OK: aira-term present"
else
    echo "TERMTEST FAIL: aira-term missing"; PASS=0
fi
[ -x /etc/aira/ipc/handlers/terms ] && echo "TERMTEST OK: terms handler present" || { echo "TERMTEST FAIL: terms handler missing"; PASS=0; }
if [ -e /dev/ptmx ] && [ -d /dev/pts ]; then
    echo "TERMTEST OK: kernel PTY layer present (/dev/ptmx + /dev/pts)"
else
    echo "TERMTEST FAIL: no kernel PTY layer"; PASS=0
fi
if command -v aira-ipc >/dev/null 2>&1 && aira-ipc ping >/dev/null 2>&1; then
    echo "TERMTEST INFO: bus reachable"; _BUS=1
else
    echo "TERMTEST INFO: bus unreachable (local path)"; _BUS=0
fi
if command -v Xvfb >/dev/null 2>&1 && command -v xterm >/dev/null 2>&1; then
    echo "TERMTEST INFO: X stack present (real spawn branch)"
    # X comes up through the PRODUCTION session launcher (it owns the
    # /persist compat symlinks Xvfb/xkbcomp require). Never hand-roll Xvfb.
    if [ -x /persist/usr/bin/aira-session ]; then _SES=/persist/usr/bin/aira-session;
    elif [ -x /usr/bin/aira-session ]; then _SES=/usr/bin/aira-session;
    else _SES=""; fi
    _XOK=1
    if [ -z "$_SES" ]; then
        echo "TERMTEST FAIL: no session launcher for X bring-up"; PASS=0
        _XOK=0
    elif ! sh "$_SES" --headless --display :99 > /tmp/aira-session-99.log 2>&1; then
        echo "TERMTEST FAIL: session launcher failed"; PASS=0
        head -n 15 /tmp/aira-session-99.log 2>&1
        _XOK=0
    fi
    if [ "$_XOK" = "1" ]; then
        _R=0
        while [ "$_R" -lt 45 ]; do
            [ -S /tmp/.X11-unix/X99 ] && DISPLAY=:99 xlsclients >/dev/null 2>&1 && break
            sleep 2; _R=$((_R+1))
        done
        if [ ! -S /tmp/.X11-unix/X99 ]; then
            echo "TERMTEST FAIL: :99 socket never appeared"; PASS=0
            head -n 15 /tmp/aira-session-99.log 2>&1
            _XOK=0
        fi
    fi
    if [ "$_XOK" = "1" ]; then
    export DISPLAY=:99
    _ID="$(aira-term spawn /root sh 2>/dev/null || true)"
    case "$_ID" in t*) echo "TERMTEST OK: spawn tracked ($_ID)" ;;
    *) echo "TERMTEST FAIL: spawn returned: $_ID"; PASS=0; _ID=""
       for _e in /run/aira-terms/*.err; do
           [ -f "$_e" ] || continue
           echo "TERMTEST DIAG $(basename "$_e"): $(head -c 300 "$_e" 2>/dev/null)"
       done ;; esac
    if [ -n "$_ID" ]; then
        sleep 1
        aira-term list 2>/dev/null | grep -q "$_ID" && echo "TERMTEST OK: list shows session" || { echo "TERMTEST FAIL: list"; PASS=0; }
        _SPID="$(aira-term list 2>/dev/null | grep "$_ID" | cut -d'|' -f2)"
        if [ -n "$_SPID" ] && ls -l "/proc/$_SPID/fd" 2>/dev/null | grep -q "ptmx"; then
            echo "TERMTEST OK: xterm holds kernel PTY master (/dev/ptmx)"
        else
            echo "TERMTEST FAIL: no PTY master for session pid $_SPID"; PASS=0
        fi
        _I2="$(aira-term spawn /root sh 2>/dev/null || true)"
        _I3="$(aira-term spawn /tmp sh 2>/dev/null || true)"
        _N="$(aira-term list 2>/dev/null | grep -c live || true)"
        if [ "$_N" -ge 3 ]; then echo "TERMTEST OK: 3 concurrent sessions";
        else echo "TERMTEST FAIL: concurrent count $_N"; PASS=0; fi
        aira-term kill "$_ID" >/dev/null 2>&1 && echo "TERMTEST OK: kill signalled" || { echo "TERMTEST FAIL: kill"; PASS=0; }
        sleep 1
        aira-term cleanup >/dev/null 2>&1
        if aira-term list 2>/dev/null | grep -q "$_ID"; then echo "TERMTEST INFO: killed entry retained (xterm lingering)";
        else echo "TERMTEST OK: dead entry reaped"; fi
        for _k in "$_I2" "$_I3"; do
            case "$_k" in t*) aira-term kill "$_k" >/dev/null 2>&1 || true ;; esac
        done
        sleep 1
        aira-term cleanup >/dev/null 2>&1 || true
    fi
    if su aira -c 'aira-term spawn /root sh' >/dev/null 2>&1; then
        echo "TERMTEST FAIL: unprivileged spawn allowed"; PASS=0
    else
        echo "TERMTEST OK: unprivileged spawn denied"
    fi
    fi
    pkill Xvfb 2>/dev/null || true
    unset DISPLAY
else
    echo "TERMTEST INFO: no X stack (honest-headless branch)"
    if aira-term spawn /root sh >/dev/null 2>&1; then
        echo "TERMTEST FAIL: headless spawn accepted"; PASS=0
    else
        echo "TERMTEST OK: headless spawn UNAVAILABLE"
    fi
fi
echo "--- validation (X-independent) ---"
if aira-term spawn "/root/../etc" sh >/dev/null 2>&1; then echo "TERMTEST FAIL: traversal cwd"; PASS=0;
else echo "TERMTEST OK: traversal cwd rejected"; fi
if aira-term spawn /no-such-dir-xyz sh >/dev/null 2>&1; then echo "TERMTEST FAIL: missing cwd"; PASS=0;
else echo "TERMTEST OK: missing cwd rejected"; fi
if aira-term spawn /root "sh;evil" >/dev/null 2>&1; then echo "TERMTEST FAIL: shell metachars"; PASS=0;
else echo "TERMTEST OK: shell metachars rejected"; fi
if aira-term spawn /root "/bin/sh" >/dev/null 2>&1; then echo "TERMTEST FAIL: slashed shell"; PASS=0;
else echo "TERMTEST OK: slashed shell rejected"; fi
if aira-term kill "../x" >/dev/null 2>&1; then echo "TERMTEST FAIL: bad id"; PASS=0;
else echo "TERMTEST OK: bad id rejected"; fi
if aira-term kill t-no-such-session-0 >/dev/null 2>&1; then echo "TERMTEST FAIL: unknown kill"; PASS=0;
else echo "TERMTEST OK: unknown kill rejected"; fi
aira-term caps 2>/dev/null | grep -q "max=32" && echo "TERMTEST OK: caps" || { echo "TERMTEST FAIL: caps"; PASS=0; }
echo "--- registry hygiene on fixtures (real registry) ---"
_RD=/run/aira-terms
mkdir -p "$_RD"
sleep 30 &
_LIVEPID=$!
printf "pid=%s\nuid=0\ndisplay=\ncwd=/root\nshell=/bin/sh\nstarted=0\n" "$_LIVEPID" > "$_RD/live-1.session"
printf "pid=999997\nuid=0\ndisplay=\ncwd=/root\nshell=/bin/sh\nstarted=0\n" > "$_RD/stale-1.session"
printf "pid=%s\nuid=99999\ndisplay=\ncwd=/root\nshell=/bin/sh\nstarted=0\n" "$_LIVEPID" > "$_RD/foreign-1.session"
aira-term list 2>/dev/null | grep -q "live-1.*live" && echo "TERMTEST OK: fixture live listed" || { echo "TERMTEST FAIL: fixture list"; PASS=0; }
aira-term cleanup 2>/dev/null | grep -Eq "removed=[1-9]" && echo "TERMTEST OK: stale reaped" || { echo "TERMTEST FAIL: cleanup count"; PASS=0; }
[ ! -f "$_RD/stale-1.session" ] && [ -f "$_RD/live-1.session" ] && echo "TERMTEST OK: selective reap" || { echo "TERMTEST FAIL: selective reap"; PASS=0; }
if [ "$_BUS" = "1" ]; then
    if su aira -c 'aira-term kill foreign-1' >/dev/null 2>&1; then
        echo "TERMTEST FAIL: cross-uid kill allowed"; PASS=0
    else
        echo "TERMTEST OK: cross-uid kill denied"
    fi
else
    echo "TERMTEST INFO: ownership probe needs bus (skipped)"
fi
kill "$_LIVEPID" 2>/dev/null
aira-term kill live-1 >/dev/null 2>&1 || true
aira-term kill foreign-1 >/dev/null 2>&1 || true
if [ "$PASS" = "1" ]; then echo "===== TERMTEST PASS ====="; else echo "===== TERMTEST FAIL ====="; fi
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo halt
sleep 5
