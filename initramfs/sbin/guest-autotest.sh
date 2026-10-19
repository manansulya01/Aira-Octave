#!/bin/sh
# In-guest automated verification (runs as init when aira_autotest=1 on cmdline).
# Prints GUEST-TEST markers to serial, then poweroff. Never hangs.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export TERM=linux
PASS=1
t() {
  desc="$1"; shift
  if "$@" >/tmp/t.out 2>&1; then echo "GUEST-TEST OK: $desc";
  else echo "GUEST-TEST FAIL: $desc"; cat /tmp/t.out; PASS=0; fi
}
t_contains() {
  desc="$1"; file="$2"; pat="$3"
  if grep -q "$pat" "$file" 2>/dev/null; then echo "GUEST-TEST OK: $desc";
  else echo "GUEST-TEST FAIL: $desc (missing '$pat')"; PASS=0; fi
}
echo "===== GUEST AUTOTEST START ====="
uname -a
cat /etc/os-release 2>/dev/null || { echo "GUEST-TEST FAIL: os-release"; PASS=0; }
# mounts from /init already done when run via /init; if run standalone, ensure basics
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null
mkdir -p /var/log/airaos /run/aira-services /tmp

echo "--- aira CLI ---"
t "aira info" /usr/bin/aira info
/usr/bin/aira info > /tmp/aira-info.out 2>&1
t_contains "aira info shows Octave" /tmp/aira-info.out "AiraOS-Octave"

echo "--- support bundle ---"
SUPPORT_BUNDLE="/tmp/aira-support-autotest.tar.gz"
SUPPORT_LIST="/tmp/aira-support-autotest.list"
rm -f "$SUPPORT_BUNDLE" "$SUPPORT_LIST"
t "support bundle create" sh -c '/usr/bin/aira support-bundle /tmp/aira-support-autotest.tar.gz >/tmp/aira-support-create.out 2>&1'
t_contains "support bundle success marker" /tmp/aira-support-create.out "SUPPORT BUNDLE CREATED"
t "support bundle archive readable" tar -tzf "$SUPPORT_BUNDLE"
tar -tzf "$SUPPORT_BUNDLE" > "$SUPPORT_LIST" 2>/dev/null
t_contains "support bundle includes system report" "$SUPPORT_LIST" "system.txt"
t_contains "support bundle includes doctor report" "$SUPPORT_LIST" "doctor.txt"
if grep -Eq '(^|/)(shadow|gshadow|passwd|root[.]token)$' "$SUPPORT_LIST"; then
  echo "GUEST-TEST FAIL: support bundle includes a credential file"; PASS=0
else
  echo "GUEST-TEST OK: support bundle excludes credential files"
fi
rm -f "$SUPPORT_BUNDLE" "$SUPPORT_LIST"
t "aira system" /usr/bin/aira system
t "aira diagnose" /usr/bin/aira diagnose
t "aira version" /usr/bin/aira version
t "aira storage" /usr/bin/aira storage
t "aira users" /usr/bin/aira users
t "aira help" /usr/bin/aira help
t "aira status" /usr/bin/aira status
t "aira network show" /usr/bin/aira network
t "aira package list" /usr/bin/aira package list
t "aira update check" /usr/bin/aira update --check
/usr/bin/aira demo > /tmp/aira-demo.out 2>&1 && grep -qi "live demo" /tmp/aira-demo.out && echo "GUEST-TEST OK: aira demo" || { echo "GUEST-TEST FAIL: aira demo"; PASS=0; }
if /usr/bin/aira shutdown 2>/dev/null; then echo "GUEST-TEST FAIL: shutdown guard"; PASS=0;
else echo "GUEST-TEST OK: shutdown guard (needs --force)"; fi
if /usr/bin/aira reboot 2>/dev/null; then echo "GUEST-TEST FAIL: reboot guard"; PASS=0;
else echo "GUEST-TEST OK: reboot guard (needs --force)"; fi

echo "--- users ---"
t_contains "passwd has aira" /etc/passwd "aira:x:1000:1000"
t "id aira" id aira
touch /home/aira/autotest-write 2>/dev/null && echo "GUEST-TEST OK: aira home writable" || echo "GUEST-TEST INFO: home write check skipped"
echo "--- permissions ---"
if su aira -c 'touch /root/aira-should-fail' 2>/dev/null; then
  echo "GUEST-TEST FAIL: aira wrote /root (DAC broken)"; rm -f /root/aira-should-fail; PASS=0
else
  echo "GUEST-TEST OK: aira cannot write /root"
fi
if su aira -c 'touch /home/aira/aira-own-write && rm -f /home/aira/aira-own-write' 2>/dev/null; then
  echo "GUEST-TEST OK: aira can write own home"
else
  echo "GUEST-TEST FAIL: aira cannot write own home"; PASS=0
fi
echo "--- security ---"
if ls -ld /root 2>/dev/null | grep -q "^drwx------"; then
  echo "GUEST-TEST OK: /root is 700"
else
  echo "GUEST-TEST FAIL: /root perms"; ls -ld /root 2>/dev/null; PASS=0
fi
SUID_OUT="$(ls -l /bin /sbin /usr/bin 2>/dev/null | grep -E "^-...s" || true)"
if [ -n "$SUID_OUT" ]; then
  echo "GUEST-TEST FAIL: setuid/setgid files present"; echo "$SUID_OUT"; PASS=0
else
  echo "GUEST-TEST OK: no setuid/setgid files in system paths"
fi
if netstat -ltn >/tmp/ns.out 2>/tmp/ns.err; then
  if grep -qE ":[0-9]+ " /tmp/ns.out; then
    echo "GUEST-TEST INFO: listeners present:"; cat /tmp/ns.out
  else
    echo "GUEST-TEST OK: no TCP listeners by default"
  fi
else
  echo "GUEST-TEST INFO: netstat unavailable ($(cat /tmp/ns.err 2>/dev/null))"
fi
echo "--- privileged processes (evidence) ---"
ps -o pid,user,comm 2>/dev/null | head -n 20 || ps 2>/dev/null | head -n 20

echo "--- services ---"
t "aira-init status" /sbin/aira-init status
/sbin/aira-init status syslog > /tmp/svc.out 2>&1
t_contains "syslog running" /tmp/svc.out "running"
/sbin/aira-init status klog > /tmp/svc-klog.out 2>&1
t_contains "klog running" /tmp/svc-klog.out "running"
t "klog single instance" sh -c 'test "$(pidof klogd 2>/dev/null | wc -w)" -eq 1'
t "service restart net" /sbin/aira-init restart net
/sbin/aira-init status net > /tmp/svc-net.out 2>&1
t_contains "net oneshot done" /tmp/svc-net.out "done"
echo "--- net oneshot log ---"
cat /var/log/airaos/net.log 2>/dev/null
echo "--- starter trace ---"
cat /var/log/airaos/trace.log 2>/dev/null
echo "--- boot services.log ---"
cat /var/log/airaos/services.log 2>/dev/null
echo "--- syslogd instances ---"
pidof syslogd 2>&1
ps -o pid,ppid,args 2>/dev/null | grep -F syslogd | grep -v grep || ps 2>/dev/null | grep -F syslogd | grep -v grep
echo "--- klogd instances (control) ---"
pidof klogd 2>&1
echo "--- starttime ticks (equal=same fork event) ---"
for p in $(pidof syslogd 2>/dev/null); do
  awk '{print $22}' /proc/$p/stat 2>/dev/null | xargs echo "pid $p starttick:"
done
t "no duplicate syslogd" sh -c 'test "$(pidof syslogd 2>/dev/null | wc -w)" -le 1'
if /sbin/aira-init start no-such-service 2>/dev/null; then echo "GUEST-TEST FAIL: unknown service accepted"; PASS=0;
else echo "GUEST-TEST OK: unknown service rejected"; fi
printf 'DESC="autotest user service"\nCMD="touch /home/aira/svc-user-marker && sleep 30"\nDEPS=""\nUSER="aira"\n' > /etc/aira/services/autotest-user.conf
t "enable test service" /sbin/aira-init enable autotest-user
echo "--- direct su probe ---"
su -s /bin/sh aira -c 'touch /home/aira/direct-marker' 2>&1; echo "su rc=$?"
ls -l /home/aira/direct-marker 2>&1
rm -f /home/aira/direct-marker
/sbin/aira-init start autotest-user > /tmp/svc-user.out 2>&1
cat /tmp/svc-user.out
cat /var/log/airaos/autotest-user.log 2>/dev/null
sleep 1
ls -ln /home/aira/svc-user-marker 2>/dev/null
if [ -f /home/aira/svc-user-marker ] && ls -ln /home/aira/svc-user-marker 2>/dev/null | grep -q " 1000  *1000 "; then
  echo "GUEST-TEST OK: service ran as aira"
else
  echo "GUEST-TEST FAIL: service user ownership"; ls -l /home/aira/svc-user-marker 2>/dev/null; PASS=0
fi
SVCPID="$(cat /run/aira-services/autotest-user.pid 2>/dev/null)"
if [ -n "$SVCPID" ]; then
  kill -9 "$SVCPID" 2>/dev/null
  sleep 0.5
  if /sbin/aira-init status autotest-user 2>/dev/null | grep -q "failed"; then
    echo "GUEST-TEST OK: crash detected as failed"
  else
    echo "GUEST-TEST FAIL: crash not detected"; PASS=0
  fi
  t "recover crashed service" /sbin/aira-init restart autotest-user
else
  echo "GUEST-TEST FAIL: no pidfile for crash test"; PASS=0
fi
t "stop test service" /sbin/aira-init stop autotest-user
if /sbin/aira-init status autotest-user 2>/dev/null | grep -q "stopped"; then
  echo "GUEST-TEST OK: stopped state reported"
else
  echo "GUEST-TEST FAIL: stopped state"; PASS=0
fi
t "disable test service" /sbin/aira-init disable autotest-user
if [ ! -e /etc/aira/enabled/autotest-user ]; then
  echo "GUEST-TEST OK: disable removed link"
else
  echo "GUEST-TEST FAIL: disable link remains"; PASS=0
fi
rm -f /etc/aira/services/autotest-user.conf /home/aira/svc-user-marker
echo "--- shutdown ordering ---"
printf 'DESC="shutdown probe"\nCMD="sleep 60"\nDEPS=""\n' > /etc/aira/services/autotest-sd.conf
/sbin/aira-init enable autotest-sd >/dev/null 2>&1
/sbin/aira-init start autotest-sd >/dev/null 2>&1
t "ordered shutdown" /sbin/aira-init shutdown
if /sbin/aira-init status autotest-sd 2>/dev/null | grep -q "stopped"; then
  echo "GUEST-TEST OK: shutdown stopped services"
else
  echo "GUEST-TEST FAIL: shutdown left services running"; PASS=0
fi
t "recover syslog after shutdown" /sbin/aira-init start syslog
t "recover klog after shutdown" /sbin/aira-init start klog
/sbin/aira-init disable autotest-sd >/dev/null 2>&1
/sbin/aira-init disable autotest-user >/dev/null 2>&1
rm -f /etc/aira/services/autotest-sd.conf /run/aira-services/autotest-sd.pid

echo "--- platform ---"
t "aira platform" /usr/bin/aira platform
/usr/bin/aira platform > /tmp/aira-platform.out 2>&1
t_contains "platform cpu" /tmp/aira-platform.out "model name"
t_contains "platform pci" /tmp/aira-platform.out "vendor="
t_contains "platform interrupts" /tmp/aira-platform.out "CPU0"
echo "--- platform listing (evidence) ---"
head -n 30 /tmp/aira-platform.out

echo "--- help/docs (C8) ---"
t "docs dir present" test -d /usr/share/doc/aira-octave
t "docs index listed" sh -c '/usr/bin/aira-help docs 2>&1 | grep -q ARCHITECTURE.md'
t "docs content readable" sh -c '/usr/bin/aira-help docs ARCHITECTURE.md 2>&1 | head -1 | grep -qi aira'
t "docs traversal rejected" sh -c '/usr/bin/aira-help docs ../../etc/passwd 2>&1 | grep -q "no such document"'
t "docs missing doc rejected" sh -c '/usr/bin/aira-help docs nope.md 2>&1 | grep -q "no such document"'
t "docs capability matrix" sh -c '/usr/bin/aira-help docs CAPABILITY-MATRIX.md 2>&1 | grep -qi "capability matrix"'
t "help topic search" sh -c '/usr/bin/aira-help terminal 2>&1 | grep -q Terminal'
t "help dash-topic no grep error" sh -c 'out=$(/usr/bin/aira-help --nosuchtopic 2>&1); case "$out" in *"invalid option"*) exit 1 ;; *) exit 0 ;; esac'
echo "--- welcome/about (C8) ---"
WHOME=/tmp/welcome-test
WDIR=$WHOME/.config/aira
WFLAG=$WDIR/welcome-done
rm -rf $WHOME; mkdir -p $WHOME
t "welcome first run" sh -c "AIRA_WELCOME_DIR=$WDIR HOME=$WHOME /usr/bin/aira-welcome </dev/null >/tmp/welcome1.out 2>&1"
t_contains "welcome greeting shown" /tmp/welcome1.out "Welcome to AiraOS-Octave"
t "welcome flag created after first run" test -f "$WFLAG"
t "welcome second run silent" sh -c "out=\$(AIRA_WELCOME_DIR=$WDIR HOME=$WHOME /usr/bin/aira-welcome </dev/null 2>&1); [ -z \"\$out\" ]"
t "welcome --force reshows" sh -c "AIRA_WELCOME_DIR=$WDIR HOME=$WHOME /usr/bin/aira-welcome --force </dev/null 2>&1 | grep -q 'Welcome to AiraOS-Octave'"
t "welcome --tour prints tour" sh -c "AIRA_WELCOME_DIR=$WDIR HOME=$WHOME /usr/bin/aira-welcome --tour </dev/null 2>&1 | grep -q 'The AiraOS Desktop'"
t "welcome --help usage" sh -c "/usr/bin/aira-welcome --help 2>&1 | grep -q 'Usage: aira-welcome'"
rm -f "$WFLAG"
t "welcome unknown arg ignored" sh -c "AIRA_WELCOME_DIR=$WDIR HOME=$WHOME /usr/bin/aira-welcome --nonsense </dev/null 2>&1 | grep -q 'Welcome to AiraOS-Octave'"
t "about shows version" sh -c '/usr/bin/aira-about 2>&1 | grep -q AiraOS-Octave'
t "about shows kernel" sh -c '/usr/bin/aira-about 2>&1 | grep -q "Kernel: Linux"'
t "about honest persistence" sh -c '/usr/bin/aira-about 2>&1 | grep -qE "Storage: (RAM only|[0-9])"'
t "help doctor launches doctor" sh -c '/usr/bin/aira-help doctor --areas ipc >/tmp/help-doctor.out 2>&1'
t_contains "doctor output has ipc area" /tmp/help-doctor.out "ipc"
echo "--- help doctor (evidence head) ---"
head -n 8 /tmp/help-doctor.out 2>/dev/null

echo "--- networking ---"
ip link set lo up 2>/dev/null
ip addr add 127.0.0.1/8 dev lo 2>/dev/null
t "ip link lo" ip link show lo
t "ping loopback" ping -c1 -W2 127.0.0.1
echo "--- loopback TCP (IPC) ---"
rm -f /tmp/nc.out
nc -l -p 19999 > /tmp/nc.out 2>&1 &
NCPID=$!
sleep 1
echo "hello-ipc" | nc -w 2 127.0.0.1 19999 2>/dev/null || true
sleep 1
kill $NCPID 2>/dev/null
if grep -q "hello-ipc" /tmp/nc.out 2>/dev/null; then
  echo "GUEST-TEST OK: loopback TCP works"
else
  echo "GUEST-TEST FAIL: loopback TCP"; cat /tmp/nc.out 2>/dev/null; PASS=0
fi
ip addr show eth0 2>/dev/null && echo "GUEST-TEST INFO: eth0 present" || echo "GUEST-TEST INFO: no eth0 (ok without --net)"

echo "--- Aira IPC bus (protocol v1) ---"
# Ensure daemon is running (earlier shutdown test stops all services).
/sbin/aira-init start ipc >/dev/null 2>&1 || true
sleep 1
ipc_raw() { # $1=request-line -> stdout response, rc preserved
  printf "%s\n" "$1" | timeout 5 nc -w 5 127.0.0.1 41234 2>/dev/null
}
if /sbin/aira-init status ipc 2>/dev/null | grep -q running; then
  echo "GUEST-TEST OK: ipc daemon running"
else
  echo "GUEST-TEST FAIL: ipc daemon not running"; /sbin/aira-init status ipc 2>&1; PASS=0
fi
# token file: root-only, non-empty
if [ -f /run/aira-ipc/root.token ]; then
  if ls -l /run/aira-ipc/root.token 2>/dev/null | grep -q "^-rw-------"; then
    echo "GUEST-TEST OK: ipc token 600"
  else
    echo "GUEST-TEST FAIL: ipc token perms"; ls -l /run/aira-ipc/root.token 2>&1; PASS=0
  fi
  if [ -s /run/aira-ipc/root.token ]; then echo "GUEST-TEST OK: ipc token non-empty";
  else echo "GUEST-TEST FAIL: ipc token empty"; PASS=0; fi
  if su aira -c 'cat /run/aira-ipc/root.token' >/dev/null 2>&1; then
    echo "GUEST-TEST FAIL: non-root read ipc token"; PASS=0
  else
    echo "GUEST-TEST OK: ipc token root-only"
  fi
else
  echo "GUEST-TEST FAIL: ipc token missing"; PASS=0
fi
t "ipc ping" aira-ipc ping hello-ipc-bus
aira-ipc ping hello-ipc-bus > /tmp/ipc-ping.out 2>&1
t_contains "ipc ping pong" /tmp/ipc-ping.out "pong"
t "ipc list" aira-ipc list
aira-ipc list > /tmp/ipc-list.out 2>&1
t_contains "ipc list bus" /tmp/ipc-list.out "bus"
t_contains "ipc list services" /tmp/ipc-list.out "services"
t_contains "ipc list system" /tmp/ipc-list.out "system"
t_contains "ipc list storage" /tmp/ipc-list.out "storage"
t_contains "ipc list network" /tmp/ipc-list.out "network"
t "ipc system version" aira-ipc call system version
t "ipc system info" aira-ipc call system info
t "ipc system uptime" aira-ipc call system uptime
t "ipc system memory" aira-ipc call system memory
t "ipc storage usage" aira-ipc call storage usage
t "ipc storage mounts" aira-ipc call storage mounts
t "ipc storage persist" aira-ipc call storage persist
t "ipc network interfaces" aira-ipc call network interfaces
t "ipc network routes" aira-ipc call network routes
t "ipc network dns" aira-ipc call network dns
t "ipc services status" aira-ipc call services status
aira-ipc call services status > /tmp/ipc-svc.out 2>&1
t_contains "ipc services shows syslog" /tmp/ipc-svc.out "syslog"
# privileged lifecycle via bus (as root: token auto-presented)
t "ipc services stop syslog" aira-ipc call services stop syslog
if aira-ipc call services status syslog 2>/dev/null | grep -q "stopped"; then
  echo "GUEST-TEST OK: ipc stop syslog effective"
else
  echo "GUEST-TEST FAIL: ipc stop syslog"; PASS=0
fi
t "ipc services start syslog" aira-ipc call services start syslog
if aira-ipc call services status syslog 2>/dev/null | grep -q "running"; then
  echo "GUEST-TEST OK: ipc start syslog effective"
else
  echo "GUEST-TEST FAIL: ipc start syslog"; PASS=0
fi
t "ipc services restart syslog" aira-ipc call services restart syslog
# events: emit + retrieve
t "ipc emit" aira-ipc emit test.topic hello-from-autotest
t "ipc events" aira-ipc events
aira-ipc events test.topic 5 > /tmp/ipc-events.out 2>&1
t_contains "ipc event stored" /tmp/ipc-events.out "test.topic"
# privileged emit denied without token (raw request, auth=none)
_R="$(ipc_raw "AIRA1|t-priv1|0:nobody|bus|emit|none|system.reboot now" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR.*denied"; then
  echo "GUEST-TEST OK: ipc denied system.* emit without token"
else
  echo "GUEST-TEST FAIL: ipc system.* emit not denied: $_R"; PASS=0
fi
# privileged service op denied without token
_R="$(ipc_raw "AIRA1|t-priv2|0:nobody|services|stop|none|syslog" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR.*denied"; then
  echo "GUEST-TEST OK: ipc denied services.stop without token"
else
  echo "GUEST-TEST FAIL: ipc services.stop not denied: $_R"; PASS=0
fi
# authorized privileged op (root token via client) already proven above by stop/start;
# explicitly verify token path works for system.* emit
t "ipc auth emit system topic" aira-ipc emit system.test autotest-priv-ok
# malformed / protocol violations (must be ERR, daemon must survive)
_R="$(ipc_raw "GARBAGE-NO-PIPES" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR"; then echo "GUEST-TEST OK: ipc malformed rejected";
else echo "GUEST-TEST FAIL: ipc malformed accepted: $_R"; PASS=0; fi
_R="$(ipc_raw "BOGUS|t1|0:root|bus|ping|none|hi" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "bad-version"; then echo "GUEST-TEST OK: ipc bad version rejected";
else echo "GUEST-TEST FAIL: ipc bad version: $_R"; PASS=0; fi
_R="$(ipc_raw "AIRA1|bad id with spaces|0:root|bus|ping|none|hi" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR"; then echo "GUEST-TEST OK: ipc bad id rejected";
else echo "GUEST-TEST FAIL: ipc bad id: $_R"; PASS=0; fi
_R="$(ipc_raw "AIRA1|t3|0:root|nosuchsvc|ping|none|hi" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "unknown-service"; then echo "GUEST-TEST OK: ipc unknown service rejected";
else echo "GUEST-TEST FAIL: ipc unknown service: $_R"; PASS=0; fi
_R="$(ipc_raw "AIRA1|t4|0:root|bus|nosuchmethod|none|hi" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR"; then echo "GUEST-TEST OK: ipc unknown method rejected";
else echo "GUEST-TEST FAIL: ipc unknown method: $_R"; PASS=0; fi
_R="$(ipc_raw "AIRA1|t5|0:root|BAD-SVC!|ping|none|hi" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR"; then echo "GUEST-TEST OK: ipc bad service name rejected";
else echo "GUEST-TEST FAIL: ipc bad service name: $_R"; PASS=0; fi
_R="$(ipc_raw "AIRA1|t6|0:root|bus|BAD-METHOD!|none|hi" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR"; then echo "GUEST-TEST OK: ipc bad method rejected";
else echo "GUEST-TEST FAIL: ipc bad method: $_R"; PASS=0; fi
# oversized request (>8192) must be rejected, daemon survives
_BIG="$(head -c 9000 /dev/zero 2>/dev/null | tr '\0' A 2>/dev/null || echo OVERSIZE-FALLBACK-PADDING-0123456789)"
_R="$(printf "AIRA1|tbig|0:root|bus|ping|none|%s\n" "$_BIG" | timeout 5 nc -w 5 127.0.0.1 41234 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "too-long"; then echo "GUEST-TEST OK: ipc oversized rejected";
else echo "GUEST-TEST FAIL: ipc oversized: $(printf "%s" "$_R" | cut -c1-80)"; PASS=0; fi
# daemon survives all abuse
t "ipc ping after abuse" aira-ipc ping survive
# repeated calls (10x)
_RC=0; i=0; while [ "$i" -lt 10 ]; do aira-ipc ping "rep$i" >/dev/null 2>&1 || _RC=1; i=$((i+1)); done
if [ "$_RC" = "0" ]; then echo "GUEST-TEST OK: ipc 10x repeated"; else echo "GUEST-TEST FAIL: ipc repeated"; PASS=0; fi
# concurrent clients (5 parallel; bus serves sequentially via nc -ll, so allow
# generous timeout under TCG load — still requires 5/5 success, just slower)
rm -f /tmp/ipc-conc-*.out
for k in 1 2 3 4 5; do ( aira-ipc call bus ping "conc$k" --timeout 20 >"/tmp/ipc-conc-$k.out" 2>&1 ) & done
wait
_COK=0; for k in 1 2 3 4 5; do grep -q pong "/tmp/ipc-conc-$k.out" 2>/dev/null && _COK=$((_COK+1)); done
if [ "$_COK" = "5" ]; then echo "GUEST-TEST OK: ipc 5x concurrent";
else echo "GUEST-TEST FAIL: ipc concurrent $_COK/5"; PASS=0; fi
# event log limit: emit 60, retrieve capped at 50
i=0; while [ "$i" -lt 60 ]; do aira-ipc emit flood.topic "msg$i" >/dev/null 2>&1 || true; i=$((i+1)); done
_N="$(aira-ipc events flood.topic 60 2>/dev/null | wc -l)"
if [ "$_N" -le 50 ] && [ "$_N" -ge 5 ]; then echo "GUEST-TEST OK: ipc event cap ($_N lines)";
else echo "GUEST-TEST FAIL: ipc event cap ($_N)"; PASS=0; fi
# handler timeout: temp slow handler (sleeps 12s > 10s handler timeout)
printf '#!/bin/sh\nsleep 12\necho slow-done\n' > /etc/aira/ipc/handlers/slowtest
chmod +x /etc/aira/ipc/handlers/slowtest
_ST="$(date +%s 2>/dev/null || echo 0)"
_R="$(printf "AIRA1|ttime|0:root|slowtest|run|none|x\n" | timeout 15 nc -w 15 127.0.0.1 41234 2>/dev/null || true)"
_ET="$(date +%s 2>/dev/null || echo 0)"
rm -f /etc/aira/ipc/handlers/slowtest
if printf "%s" "$_R" | grep -q "timeout"; then echo "GUEST-TEST OK: ipc handler timeout";
else echo "GUEST-TEST FAIL: ipc handler timeout: $(printf "%s" "$_R" | cut -c1-100)"; PASS=0; fi
t "ipc ping after timeout" aira-ipc ping after-timeout
# service failure: kill syslog, bus must report failed, restart recovers
_SVCPID="$(cat /run/aira-services/syslog.pid 2>/dev/null)"
if [ -n "$_SVCPID" ]; then
  kill -9 "$_SVCPID" 2>/dev/null; sleep 0.5
  if aira-ipc call services status syslog 2>/dev/null | grep -q "failed"; then
    echo "GUEST-TEST OK: ipc reports crashed service as failed"
  else
    echo "GUEST-TEST FAIL: ipc crash not reported"; PASS=0
  fi
  t "ipc recover crashed service" aira-ipc call services restart syslog
else
  echo "GUEST-TEST FAIL: no syslog pid for crash test"; PASS=0
fi
# daemon failure + recovery
_IPCPID="$(cat /run/aira-services/ipc.pid 2>/dev/null)"
if [ -n "$_IPCPID" ]; then
  kill -9 "$_IPCPID" 2>/dev/null; sleep 0.5
  if aira-ipc ping 2>/dev/null; then echo "GUEST-TEST FAIL: ipc alive after kill"; PASS=0;
  else echo "GUEST-TEST OK: ipc unreachable after kill"; fi
  t "ipc daemon restart" /sbin/aira-init restart ipc
  sleep 1
  t "ipc ping after restart" aira-ipc ping revived
else
  echo "GUEST-TEST FAIL: no ipc pid"; PASS=0
fi
# real integration: aira status + doctor must use the bus
/usr/bin/aira status > /tmp/aira-status-ipc.out 2>&1
t_contains "aira status via IPC" /tmp/aira-status-ipc.out "via IPC bus"
/usr/bin/aira doctor > /tmp/aira-doctor.out 2>&1 && echo "GUEST-TEST OK: aira doctor" || { echo "GUEST-TEST FAIL: aira doctor"; cat /tmp/aira-doctor.out 2>&1; PASS=0; }
# aira-doctor (C7) reports "area check STATUS detail" in a column-aligned
# layout, so assertions must tolerate the padding between fields.
t_contains "doctor ipc bus PASS" /tmp/aira-doctor.out "ipc  *bus  *PASS"
t_contains "doctor kernel release" /tmp/aira-doctor.out "kernel  *release  *PASS"
t_contains "doctor storage df" /tmp/aira-doctor.out "storage  *df  *PASS"
/usr/bin/aira-doctor --json > /tmp/aira-doctor.json 2>&1
t_contains "doctor json" /tmp/aira-doctor.json '"summary"'
t_contains "doctor json checks" /tmp/aira-doctor.json '"checks"'

echo "--- storage ---"
df > /tmp/df.out 2>&1 && echo "GUEST-TEST OK: df works" || { echo "GUEST-TEST FAIL: df"; PASS=0; }
if [ -b /dev/vda ]; then
  mkdir -p /persist
  if mount 2>/dev/null | grep -q " /persist "; then
    echo "GUEST-TEST OK: /dev/vda mounted (/persist already mounted by /init)"
  elif mount -t ext4 /dev/vda /persist 2>/dev/null; then
    echo "GUEST-TEST OK: /dev/vda mounted"
  else
    echo "GUEST-TEST INFO: /dev/vda present but mount failed (may need mkfs)"
  fi
  if mount 2>/dev/null | grep -q " /persist "; then
    if [ -f /persist/autotest-marker ]; then
      echo "GUEST-TEST OK: persist-exists from previous boot: $(cat /persist/autotest-marker)"
    else
      echo "GUEST-TEST INFO: no previous persist marker (first boot with this disk)"
    fi
    echo "persist-autotest-$(date +%s 2>/dev/null || echo manual)" > /persist/autotest-marker 2>/dev/null && echo "GUEST-TEST OK: persist write" || { echo "GUEST-TEST FAIL: persist write"; PASS=0; }
    cat /persist/autotest-marker 2>/dev/null
    sync
  fi
else
  echo "GUEST-TEST INFO: no /dev/vda (boot with --drive for persistence test)"
fi

echo "--- packages ---"
mkdir -p /tmp/pkgtest/usr/share/aira
cat > /tmp/pkgtest/PKGINFO <<'EOF'
NAME="hello-aira"
VERSION="1.0"
DESC="test package"
DEPS=""
EOF
echo "hello aira" > /tmp/pkgtest/usr/share/aira/hello.txt
t "airapkg build" airapkg build /tmp/pkgtest /tmp/hello-aira.apkg
cp -f /tmp/hello-aira.apkg /var/lib/airapkg/repo/ 2>/dev/null || true
t "airapkg search" airapkg search hello
t "airapkg info" airapkg info hello-aira
t "airapkg update-check" airapkg update-check
t "airapkg install" airapkg install /tmp/hello-aira.apkg
t_contains "package file installed" /tmp/t.out "hello-aira"
[ -f /usr/share/aira/hello.txt ] && echo "GUEST-TEST OK: payload present" || { echo "GUEST-TEST FAIL: payload missing"; PASS=0; }
t "airapkg verify" airapkg verify hello-aira
t "airapkg remove" airapkg remove hello-aira
[ ! -f /usr/share/aira/hello.txt ] && echo "GUEST-TEST OK: payload cleaned" || { echo "GUEST-TEST FAIL: payload not cleaned"; PASS=0; }
rm -f /var/lib/airapkg/repo/hello-aira.apkg
if airapkg install /tmp/does-not-exist.apkg 2>/dev/null; then echo "GUEST-TEST FAIL: invalid package accepted"; PASS=0;
else echo "GUEST-TEST OK: invalid package rejected"; fi
echo "corrupt-data" > /tmp/corrupt.apkg
if airapkg install /tmp/corrupt.apkg 2>/dev/null; then echo "GUEST-TEST FAIL: corrupt package accepted"; PASS=0;
else echo "GUEST-TEST OK: corrupt package rejected"; fi
rm -f /tmp/corrupt.apkg
# malicious archives (must be sandboxed)
mkdir -p /tmp/mal-abs/usr/share
printf 'NAME="mal-abs"\nVERSION="1.0"\nDESC="x"\nDEPS=""\n' > /tmp/mal-abs/PKGINFO
echo "evil" > /tmp/mal-abs/usr/share/evil.txt
# craft absolute-path archive (bypass airapkg build)
tar -czf /tmp/mal-abs.apkg -C / -tmp/mal-abs/usr/share/evil.txt 2>/dev/null || true
# Instead craft via explicit absolute member using python if available, else simulate via tar transform
# Simpler: test the validation directly by crafting a tar with ../
mkdir -p /tmp/mal-trav
printf 'NAME="mal-trav"\nVERSION="1.0"\nDESC="x"\nDEPS=""\n' > /tmp/mal-trav/PKGINFO
mkdir -p /tmp/mal-trav/payload
echo "evil" > /tmp/mal-trav/payload/evil.txt
# Create tar with traversal member
tar -czf /tmp/mal-trav.apkg -C /tmp/mal-trav payload/evil.txt --transform 's,payload/,../,' 2>/dev/null || tar -czf /tmp/mal-trav.apkg -C /tmp payload 2>/dev/null || true
if airapkg install /tmp/mal-trav.apkg 2>/dev/null; then echo "GUEST-TEST FAIL: traversal accepted"; PASS=0;
else echo "GUEST-TEST OK: traversal rejected"; fi
rm -rf /tmp/mal-abs /tmp/mal-abs.apkg /tmp/mal-trav /tmp/mal-trav.apkg
# symlink escape: create pkg with symlink
mkdir -p /tmp/mal-link
printf 'NAME="mal-link"\nVERSION="1.0"\nDESC="x"\nDEPS=""\n' > /tmp/mal-link/PKGINFO
ln -sf /etc/passwd /tmp/mal-link/evil-link 2>/dev/null || true
tar -czf /tmp/mal-link.apkg -C /tmp/mal-link . 2>/dev/null || true
if airapkg install /tmp/mal-link.apkg 2>/dev/null; then echo "GUEST-TEST FAIL: symlink accepted"; PASS=0;
else echo "GUEST-TEST OK: symlink rejected"; fi
rm -rf /tmp/mal-link /tmp/mal-link.apkg
echo "--- rollback ---"
mkdir -p /tmp/rbtest/usr/share/aira
printf 'NAME="rbtest"\nVERSION="2.0"\nDESC="rollback test"\nDEPS=""\n' > /tmp/rbtest/PKGINFO
echo "v1-content" > /usr/share/aira/rb.txt
echo "v2-content" > /tmp/rbtest/usr/share/aira/rb.txt
t "rollback pkg build" airapkg build /tmp/rbtest /tmp/rbtest.apkg
t "rollback pkg install" airapkg install /tmp/rbtest.apkg
[ "$(cat /usr/share/aira/rb.txt 2>/dev/null)" = "v2-content" ] && echo "GUEST-TEST OK: v2 installed" || { echo "GUEST-TEST FAIL: v2 content"; PASS=0; }
t "rollback restore" airapkg rollback rbtest
[ "$(cat /usr/share/aira/rb.txt 2>/dev/null)" = "v1-content" ] && echo "GUEST-TEST OK: rollback restored v1" || { echo "GUEST-TEST FAIL: rollback content"; PASS=0; }
t "rollback pkg remove" airapkg remove rbtest
rm -rf /tmp/rbtest /tmp/rbtest.apkg /usr/share/aira/rb.txt
mkdir -p /tmp/deptest
printf 'NAME="deptest"\nVERSION="1.0"\nDESC="dep test"\nDEPS="missing-dep-xyz"\n' > /tmp/deptest/PKGINFO
airapkg build /tmp/deptest /tmp/deptest.apkg >/dev/null 2>&1
if airapkg install /tmp/deptest.apkg 2>&1 | grep -q "WARN: dependency"; then
  echo "GUEST-TEST OK: missing dep warns"
else
  echo "GUEST-TEST FAIL: missing dep warning"; PASS=0
fi
airapkg remove deptest >/dev/null 2>&1
rm -rf /tmp/deptest /tmp/deptest.apkg
echo "--- sample app (dev workflow) ---"
SAMPLE_APKG=""
for cand in /var/lib/airapkg/repo/hello-aira-1.0.apkg /persist/var/lib/airapkg/repo/hello-aira-1.0.apkg; do
  if [ -f "$cand" ]; then SAMPLE_APKG="$cand"; break; fi
done
if [ -n "$SAMPLE_APKG" ]; then
  echo "sample apkg: $SAMPLE_APKG"
  t "sample install" airapkg install "$SAMPLE_APKG"
  if [ "$(/usr/share/aira-samples/hello-aira 2>/dev/null)" = "hello from AiraOS-Octave sample v1.0" ]; then
    echo "GUEST-TEST OK: sample executes with exact output"
  else
    echo "GUEST-TEST FAIL: sample output"; /usr/share/aira-samples/hello-aira 2>&1; PASS=0
  fi
  t "sample remove" airapkg remove hello-aira
else
  echo "GUEST-TEST INFO: sample .apkg not in repo image (dev image only)"
fi

echo "--- gui (if requested) ---"
if grep -q "aira_guitest=1" /proc/cmdline 2>/dev/null; then
  # GUI lives in /persist (rootfs.img); extend PATH/LD so Xvfb/jwm run
  if [ -d /persist/usr/bin ]; then
    export PATH=/persist/usr/bin:/persist/bin:/persist/sbin:$PATH
    export LD_LIBRARY_PATH=/persist/usr/lib/x86_64-linux-gnu:/persist/lib/x86_64-linux-gnu:/persist/usr/lib:$LD_LIBRARY_PATH
    echo "GUI-TEST: using /persist GUI stack"
    if [ -x /persist/usr/bin/aira-gui-test ]; then
      if /persist/usr/bin/aira-gui-test 2>&1; then echo "GUEST-TEST OK: gui";
      else echo "GUEST-TEST FAIL: gui"; PASS=0; fi
    elif [ -x /usr/bin/aira-gui-test ]; then
      if /usr/bin/aira-gui-test 2>&1; then echo "GUEST-TEST OK: gui";
      else echo "GUEST-TEST FAIL: gui"; PASS=0; fi
    else
      echo "GUEST-TEST FAIL: aira-gui-test not found (build-gui.sh missing?)"; PASS=0
    fi
  else
    echo "GUEST-TEST FAIL: /persist/usr/bin missing (boot with --drive aira-rootfs.img after build-gui)"; PASS=0
  fi
else
  echo "GUI-TEST: skipped (no aira_guitest=1)"
fi

if [ "$PASS" = "1" ]; then echo "===== GUEST AUTOTEST PASS =====";
else echo "===== GUEST AUTOTEST FAIL ====="; fi
echo "powering off"
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo "halt"
sleep 5
 "$SUPPORT_LIST"; then
  echo "GUEST-TEST FAIL: support bundle includes a credential or resolver file"; PASS=0
else
  echo "GUEST-TEST OK: support bundle excludes credential files and raw resolver file"
fi
rm -f "$SUPPORT_BUNDLE" "$SUPPORT_LIST"
t "aira system" /usr/bin/aira system
t "aira diagnose" /usr/bin/aira diagnose
t "aira version" /usr/bin/aira version
t "aira storage" /usr/bin/aira storage
t "aira users" /usr/bin/aira users
t "aira help" /usr/bin/aira help
t "aira status" /usr/bin/aira status
t "aira network show" /usr/bin/aira network
t "aira package list" /usr/bin/aira package list
t "aira update check" /usr/bin/aira update --check
/usr/bin/aira demo > /tmp/aira-demo.out 2>&1 && grep -qi "live demo" /tmp/aira-demo.out && echo "GUEST-TEST OK: aira demo" || { echo "GUEST-TEST FAIL: aira demo"; PASS=0; }
if /usr/bin/aira shutdown 2>/dev/null; then echo "GUEST-TEST FAIL: shutdown guard"; PASS=0;
else echo "GUEST-TEST OK: shutdown guard (needs --force)"; fi
if /usr/bin/aira reboot 2>/dev/null; then echo "GUEST-TEST FAIL: reboot guard"; PASS=0;
else echo "GUEST-TEST OK: reboot guard (needs --force)"; fi

echo "--- users ---"
t_contains "passwd has aira" /etc/passwd "aira:x:1000:1000"
t "id aira" id aira
touch /home/aira/autotest-write 2>/dev/null && echo "GUEST-TEST OK: aira home writable" || echo "GUEST-TEST INFO: home write check skipped"
echo "--- permissions ---"
if su aira -c 'touch /root/aira-should-fail' 2>/dev/null; then
  echo "GUEST-TEST FAIL: aira wrote /root (DAC broken)"; rm -f /root/aira-should-fail; PASS=0
else
  echo "GUEST-TEST OK: aira cannot write /root"
fi
if su aira -c 'touch /home/aira/aira-own-write && rm -f /home/aira/aira-own-write' 2>/dev/null; then
  echo "GUEST-TEST OK: aira can write own home"
else
  echo "GUEST-TEST FAIL: aira cannot write own home"; PASS=0
fi
echo "--- security ---"
if ls -ld /root 2>/dev/null | grep -q "^drwx------"; then
  echo "GUEST-TEST OK: /root is 700"
else
  echo "GUEST-TEST FAIL: /root perms"; ls -ld /root 2>/dev/null; PASS=0
fi
SUID_OUT="$(ls -l /bin /sbin /usr/bin 2>/dev/null | grep -E "^-...s" || true)"
if [ -n "$SUID_OUT" ]; then
  echo "GUEST-TEST FAIL: setuid/setgid files present"; echo "$SUID_OUT"; PASS=0
else
  echo "GUEST-TEST OK: no setuid/setgid files in system paths"
fi
if netstat -ltn >/tmp/ns.out 2>/tmp/ns.err; then
  if grep -qE ":[0-9]+ " /tmp/ns.out; then
    echo "GUEST-TEST INFO: listeners present:"; cat /tmp/ns.out
  else
    echo "GUEST-TEST OK: no TCP listeners by default"
  fi
else
  echo "GUEST-TEST INFO: netstat unavailable ($(cat /tmp/ns.err 2>/dev/null))"
fi
echo "--- privileged processes (evidence) ---"
ps -o pid,user,comm 2>/dev/null | head -n 20 || ps 2>/dev/null | head -n 20

echo "--- services ---"
t "aira-init status" /sbin/aira-init status
/sbin/aira-init status syslog > /tmp/svc.out 2>&1
t_contains "syslog running" /tmp/svc.out "running"
/sbin/aira-init status klog > /tmp/svc-klog.out 2>&1
t_contains "klog running" /tmp/svc-klog.out "running"
t "klog single instance" sh -c 'test "$(pidof klogd 2>/dev/null | wc -w)" -eq 1'
t "service restart net" /sbin/aira-init restart net
/sbin/aira-init status net > /tmp/svc-net.out 2>&1
t_contains "net oneshot done" /tmp/svc-net.out "done"
echo "--- net oneshot log ---"
cat /var/log/airaos/net.log 2>/dev/null
echo "--- starter trace ---"
cat /var/log/airaos/trace.log 2>/dev/null
echo "--- boot services.log ---"
cat /var/log/airaos/services.log 2>/dev/null
echo "--- syslogd instances ---"
pidof syslogd 2>&1
ps -o pid,ppid,args 2>/dev/null | grep -F syslogd | grep -v grep || ps 2>/dev/null | grep -F syslogd | grep -v grep
echo "--- klogd instances (control) ---"
pidof klogd 2>&1
echo "--- starttime ticks (equal=same fork event) ---"
for p in $(pidof syslogd 2>/dev/null); do
  awk '{print $22}' /proc/$p/stat 2>/dev/null | xargs echo "pid $p starttick:"
done
t "no duplicate syslogd" sh -c 'test "$(pidof syslogd 2>/dev/null | wc -w)" -le 1'
if /sbin/aira-init start no-such-service 2>/dev/null; then echo "GUEST-TEST FAIL: unknown service accepted"; PASS=0;
else echo "GUEST-TEST OK: unknown service rejected"; fi
printf 'DESC="autotest user service"\nCMD="touch /home/aira/svc-user-marker && sleep 30"\nDEPS=""\nUSER="aira"\n' > /etc/aira/services/autotest-user.conf
t "enable test service" /sbin/aira-init enable autotest-user
echo "--- direct su probe ---"
su -s /bin/sh aira -c 'touch /home/aira/direct-marker' 2>&1; echo "su rc=$?"
ls -l /home/aira/direct-marker 2>&1
rm -f /home/aira/direct-marker
/sbin/aira-init start autotest-user > /tmp/svc-user.out 2>&1
cat /tmp/svc-user.out
cat /var/log/airaos/autotest-user.log 2>/dev/null
sleep 1
ls -ln /home/aira/svc-user-marker 2>/dev/null
if [ -f /home/aira/svc-user-marker ] && ls -ln /home/aira/svc-user-marker 2>/dev/null | grep -q " 1000  *1000 "; then
  echo "GUEST-TEST OK: service ran as aira"
else
  echo "GUEST-TEST FAIL: service user ownership"; ls -l /home/aira/svc-user-marker 2>/dev/null; PASS=0
fi
SVCPID="$(cat /run/aira-services/autotest-user.pid 2>/dev/null)"
if [ -n "$SVCPID" ]; then
  kill -9 "$SVCPID" 2>/dev/null
  sleep 0.5
  if /sbin/aira-init status autotest-user 2>/dev/null | grep -q "failed"; then
    echo "GUEST-TEST OK: crash detected as failed"
  else
    echo "GUEST-TEST FAIL: crash not detected"; PASS=0
  fi
  t "recover crashed service" /sbin/aira-init restart autotest-user
else
  echo "GUEST-TEST FAIL: no pidfile for crash test"; PASS=0
fi
t "stop test service" /sbin/aira-init stop autotest-user
if /sbin/aira-init status autotest-user 2>/dev/null | grep -q "stopped"; then
  echo "GUEST-TEST OK: stopped state reported"
else
  echo "GUEST-TEST FAIL: stopped state"; PASS=0
fi
t "disable test service" /sbin/aira-init disable autotest-user
if [ ! -e /etc/aira/enabled/autotest-user ]; then
  echo "GUEST-TEST OK: disable removed link"
else
  echo "GUEST-TEST FAIL: disable link remains"; PASS=0
fi
rm -f /etc/aira/services/autotest-user.conf /home/aira/svc-user-marker
echo "--- shutdown ordering ---"
printf 'DESC="shutdown probe"\nCMD="sleep 60"\nDEPS=""\n' > /etc/aira/services/autotest-sd.conf
/sbin/aira-init enable autotest-sd >/dev/null 2>&1
/sbin/aira-init start autotest-sd >/dev/null 2>&1
t "ordered shutdown" /sbin/aira-init shutdown
if /sbin/aira-init status autotest-sd 2>/dev/null | grep -q "stopped"; then
  echo "GUEST-TEST OK: shutdown stopped services"
else
  echo "GUEST-TEST FAIL: shutdown left services running"; PASS=0
fi
t "recover syslog after shutdown" /sbin/aira-init start syslog
t "recover klog after shutdown" /sbin/aira-init start klog
/sbin/aira-init disable autotest-sd >/dev/null 2>&1
/sbin/aira-init disable autotest-user >/dev/null 2>&1
rm -f /etc/aira/services/autotest-sd.conf /run/aira-services/autotest-sd.pid

echo "--- platform ---"
t "aira platform" /usr/bin/aira platform
/usr/bin/aira platform > /tmp/aira-platform.out 2>&1
t_contains "platform cpu" /tmp/aira-platform.out "model name"
t_contains "platform pci" /tmp/aira-platform.out "vendor="
t_contains "platform interrupts" /tmp/aira-platform.out "CPU0"
echo "--- platform listing (evidence) ---"
head -n 30 /tmp/aira-platform.out

echo "--- help/docs (C8) ---"
t "docs dir present" test -d /usr/share/doc/aira-octave
t "docs index listed" sh -c '/usr/bin/aira-help docs 2>&1 | grep -q ARCHITECTURE.md'
t "docs content readable" sh -c '/usr/bin/aira-help docs ARCHITECTURE.md 2>&1 | head -1 | grep -qi aira'
t "docs traversal rejected" sh -c '/usr/bin/aira-help docs ../../etc/passwd 2>&1 | grep -q "no such document"'
t "docs missing doc rejected" sh -c '/usr/bin/aira-help docs nope.md 2>&1 | grep -q "no such document"'
t "docs capability matrix" sh -c '/usr/bin/aira-help docs CAPABILITY-MATRIX.md 2>&1 | grep -qi "capability matrix"'
t "help topic search" sh -c '/usr/bin/aira-help terminal 2>&1 | grep -q Terminal'
t "help dash-topic no grep error" sh -c 'out=$(/usr/bin/aira-help --nosuchtopic 2>&1); case "$out" in *"invalid option"*) exit 1 ;; *) exit 0 ;; esac'
echo "--- welcome/about (C8) ---"
WHOME=/tmp/welcome-test
WDIR=$WHOME/.config/aira
WFLAG=$WDIR/welcome-done
rm -rf $WHOME; mkdir -p $WHOME
t "welcome first run" sh -c "AIRA_WELCOME_DIR=$WDIR HOME=$WHOME /usr/bin/aira-welcome </dev/null >/tmp/welcome1.out 2>&1"
t_contains "welcome greeting shown" /tmp/welcome1.out "Welcome to AiraOS-Octave"
t "welcome flag created after first run" test -f "$WFLAG"
t "welcome second run silent" sh -c "out=\$(AIRA_WELCOME_DIR=$WDIR HOME=$WHOME /usr/bin/aira-welcome </dev/null 2>&1); [ -z \"\$out\" ]"
t "welcome --force reshows" sh -c "AIRA_WELCOME_DIR=$WDIR HOME=$WHOME /usr/bin/aira-welcome --force </dev/null 2>&1 | grep -q 'Welcome to AiraOS-Octave'"
t "welcome --tour prints tour" sh -c "AIRA_WELCOME_DIR=$WDIR HOME=$WHOME /usr/bin/aira-welcome --tour </dev/null 2>&1 | grep -q 'The AiraOS Desktop'"
t "welcome --help usage" sh -c "/usr/bin/aira-welcome --help 2>&1 | grep -q 'Usage: aira-welcome'"
rm -f "$WFLAG"
t "welcome unknown arg ignored" sh -c "AIRA_WELCOME_DIR=$WDIR HOME=$WHOME /usr/bin/aira-welcome --nonsense </dev/null 2>&1 | grep -q 'Welcome to AiraOS-Octave'"
t "about shows version" sh -c '/usr/bin/aira-about 2>&1 | grep -q AiraOS-Octave'
t "about shows kernel" sh -c '/usr/bin/aira-about 2>&1 | grep -q "Kernel: Linux"'
t "about honest persistence" sh -c '/usr/bin/aira-about 2>&1 | grep -qE "Storage: (RAM only|[0-9])"'
t "help doctor launches doctor" sh -c '/usr/bin/aira-help doctor --areas ipc >/tmp/help-doctor.out 2>&1'
t_contains "doctor output has ipc area" /tmp/help-doctor.out "ipc"
echo "--- help doctor (evidence head) ---"
head -n 8 /tmp/help-doctor.out 2>/dev/null

echo "--- networking ---"
ip link set lo up 2>/dev/null
ip addr add 127.0.0.1/8 dev lo 2>/dev/null
t "ip link lo" ip link show lo
t "ping loopback" ping -c1 -W2 127.0.0.1
echo "--- loopback TCP (IPC) ---"
rm -f /tmp/nc.out
nc -l -p 19999 > /tmp/nc.out 2>&1 &
NCPID=$!
sleep 1
echo "hello-ipc" | nc -w 2 127.0.0.1 19999 2>/dev/null || true
sleep 1
kill $NCPID 2>/dev/null
if grep -q "hello-ipc" /tmp/nc.out 2>/dev/null; then
  echo "GUEST-TEST OK: loopback TCP works"
else
  echo "GUEST-TEST FAIL: loopback TCP"; cat /tmp/nc.out 2>/dev/null; PASS=0
fi
ip addr show eth0 2>/dev/null && echo "GUEST-TEST INFO: eth0 present" || echo "GUEST-TEST INFO: no eth0 (ok without --net)"

echo "--- Aira IPC bus (protocol v1) ---"
# Ensure daemon is running (earlier shutdown test stops all services).
/sbin/aira-init start ipc >/dev/null 2>&1 || true
sleep 1
ipc_raw() { # $1=request-line -> stdout response, rc preserved
  printf "%s\n" "$1" | timeout 5 nc -w 5 127.0.0.1 41234 2>/dev/null
}
if /sbin/aira-init status ipc 2>/dev/null | grep -q running; then
  echo "GUEST-TEST OK: ipc daemon running"
else
  echo "GUEST-TEST FAIL: ipc daemon not running"; /sbin/aira-init status ipc 2>&1; PASS=0
fi
# token file: root-only, non-empty
if [ -f /run/aira-ipc/root.token ]; then
  if ls -l /run/aira-ipc/root.token 2>/dev/null | grep -q "^-rw-------"; then
    echo "GUEST-TEST OK: ipc token 600"
  else
    echo "GUEST-TEST FAIL: ipc token perms"; ls -l /run/aira-ipc/root.token 2>&1; PASS=0
  fi
  if [ -s /run/aira-ipc/root.token ]; then echo "GUEST-TEST OK: ipc token non-empty";
  else echo "GUEST-TEST FAIL: ipc token empty"; PASS=0; fi
  if su aira -c 'cat /run/aira-ipc/root.token' >/dev/null 2>&1; then
    echo "GUEST-TEST FAIL: non-root read ipc token"; PASS=0
  else
    echo "GUEST-TEST OK: ipc token root-only"
  fi
else
  echo "GUEST-TEST FAIL: ipc token missing"; PASS=0
fi
t "ipc ping" aira-ipc ping hello-ipc-bus
aira-ipc ping hello-ipc-bus > /tmp/ipc-ping.out 2>&1
t_contains "ipc ping pong" /tmp/ipc-ping.out "pong"
t "ipc list" aira-ipc list
aira-ipc list > /tmp/ipc-list.out 2>&1
t_contains "ipc list bus" /tmp/ipc-list.out "bus"
t_contains "ipc list services" /tmp/ipc-list.out "services"
t_contains "ipc list system" /tmp/ipc-list.out "system"
t_contains "ipc list storage" /tmp/ipc-list.out "storage"
t_contains "ipc list network" /tmp/ipc-list.out "network"
t "ipc system version" aira-ipc call system version
t "ipc system info" aira-ipc call system info
t "ipc system uptime" aira-ipc call system uptime
t "ipc system memory" aira-ipc call system memory
t "ipc storage usage" aira-ipc call storage usage
t "ipc storage mounts" aira-ipc call storage mounts
t "ipc storage persist" aira-ipc call storage persist
t "ipc network interfaces" aira-ipc call network interfaces
t "ipc network routes" aira-ipc call network routes
t "ipc network dns" aira-ipc call network dns
t "ipc services status" aira-ipc call services status
aira-ipc call services status > /tmp/ipc-svc.out 2>&1
t_contains "ipc services shows syslog" /tmp/ipc-svc.out "syslog"
# privileged lifecycle via bus (as root: token auto-presented)
t "ipc services stop syslog" aira-ipc call services stop syslog
if aira-ipc call services status syslog 2>/dev/null | grep -q "stopped"; then
  echo "GUEST-TEST OK: ipc stop syslog effective"
else
  echo "GUEST-TEST FAIL: ipc stop syslog"; PASS=0
fi
t "ipc services start syslog" aira-ipc call services start syslog
if aira-ipc call services status syslog 2>/dev/null | grep -q "running"; then
  echo "GUEST-TEST OK: ipc start syslog effective"
else
  echo "GUEST-TEST FAIL: ipc start syslog"; PASS=0
fi
t "ipc services restart syslog" aira-ipc call services restart syslog
# events: emit + retrieve
t "ipc emit" aira-ipc emit test.topic hello-from-autotest
t "ipc events" aira-ipc events
aira-ipc events test.topic 5 > /tmp/ipc-events.out 2>&1
t_contains "ipc event stored" /tmp/ipc-events.out "test.topic"
# privileged emit denied without token (raw request, auth=none)
_R="$(ipc_raw "AIRA1|t-priv1|0:nobody|bus|emit|none|system.reboot now" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR.*denied"; then
  echo "GUEST-TEST OK: ipc denied system.* emit without token"
else
  echo "GUEST-TEST FAIL: ipc system.* emit not denied: $_R"; PASS=0
fi
# privileged service op denied without token
_R="$(ipc_raw "AIRA1|t-priv2|0:nobody|services|stop|none|syslog" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR.*denied"; then
  echo "GUEST-TEST OK: ipc denied services.stop without token"
else
  echo "GUEST-TEST FAIL: ipc services.stop not denied: $_R"; PASS=0
fi
# authorized privileged op (root token via client) already proven above by stop/start;
# explicitly verify token path works for system.* emit
t "ipc auth emit system topic" aira-ipc emit system.test autotest-priv-ok
# malformed / protocol violations (must be ERR, daemon must survive)
_R="$(ipc_raw "GARBAGE-NO-PIPES" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR"; then echo "GUEST-TEST OK: ipc malformed rejected";
else echo "GUEST-TEST FAIL: ipc malformed accepted: $_R"; PASS=0; fi
_R="$(ipc_raw "BOGUS|t1|0:root|bus|ping|none|hi" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "bad-version"; then echo "GUEST-TEST OK: ipc bad version rejected";
else echo "GUEST-TEST FAIL: ipc bad version: $_R"; PASS=0; fi
_R="$(ipc_raw "AIRA1|bad id with spaces|0:root|bus|ping|none|hi" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR"; then echo "GUEST-TEST OK: ipc bad id rejected";
else echo "GUEST-TEST FAIL: ipc bad id: $_R"; PASS=0; fi
_R="$(ipc_raw "AIRA1|t3|0:root|nosuchsvc|ping|none|hi" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "unknown-service"; then echo "GUEST-TEST OK: ipc unknown service rejected";
else echo "GUEST-TEST FAIL: ipc unknown service: $_R"; PASS=0; fi
_R="$(ipc_raw "AIRA1|t4|0:root|bus|nosuchmethod|none|hi" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR"; then echo "GUEST-TEST OK: ipc unknown method rejected";
else echo "GUEST-TEST FAIL: ipc unknown method: $_R"; PASS=0; fi
_R="$(ipc_raw "AIRA1|t5|0:root|BAD-SVC!|ping|none|hi" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR"; then echo "GUEST-TEST OK: ipc bad service name rejected";
else echo "GUEST-TEST FAIL: ipc bad service name: $_R"; PASS=0; fi
_R="$(ipc_raw "AIRA1|t6|0:root|bus|BAD-METHOD!|none|hi" 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "ERR"; then echo "GUEST-TEST OK: ipc bad method rejected";
else echo "GUEST-TEST FAIL: ipc bad method: $_R"; PASS=0; fi
# oversized request (>8192) must be rejected, daemon survives
_BIG="$(head -c 9000 /dev/zero 2>/dev/null | tr '\0' A 2>/dev/null || echo OVERSIZE-FALLBACK-PADDING-0123456789)"
_R="$(printf "AIRA1|tbig|0:root|bus|ping|none|%s\n" "$_BIG" | timeout 5 nc -w 5 127.0.0.1 41234 2>/dev/null || true)"
if printf "%s" "$_R" | grep -q "too-long"; then echo "GUEST-TEST OK: ipc oversized rejected";
else echo "GUEST-TEST FAIL: ipc oversized: $(printf "%s" "$_R" | cut -c1-80)"; PASS=0; fi
# daemon survives all abuse
t "ipc ping after abuse" aira-ipc ping survive
# repeated calls (10x)
_RC=0; i=0; while [ "$i" -lt 10 ]; do aira-ipc ping "rep$i" >/dev/null 2>&1 || _RC=1; i=$((i+1)); done
if [ "$_RC" = "0" ]; then echo "GUEST-TEST OK: ipc 10x repeated"; else echo "GUEST-TEST FAIL: ipc repeated"; PASS=0; fi
# concurrent clients (5 parallel; bus serves sequentially via nc -ll, so allow
# generous timeout under TCG load — still requires 5/5 success, just slower)
rm -f /tmp/ipc-conc-*.out
for k in 1 2 3 4 5; do ( aira-ipc call bus ping "conc$k" --timeout 20 >"/tmp/ipc-conc-$k.out" 2>&1 ) & done
wait
_COK=0; for k in 1 2 3 4 5; do grep -q pong "/tmp/ipc-conc-$k.out" 2>/dev/null && _COK=$((_COK+1)); done
if [ "$_COK" = "5" ]; then echo "GUEST-TEST OK: ipc 5x concurrent";
else echo "GUEST-TEST FAIL: ipc concurrent $_COK/5"; PASS=0; fi
# event log limit: emit 60, retrieve capped at 50
i=0; while [ "$i" -lt 60 ]; do aira-ipc emit flood.topic "msg$i" >/dev/null 2>&1 || true; i=$((i+1)); done
_N="$(aira-ipc events flood.topic 60 2>/dev/null | wc -l)"
if [ "$_N" -le 50 ] && [ "$_N" -ge 5 ]; then echo "GUEST-TEST OK: ipc event cap ($_N lines)";
else echo "GUEST-TEST FAIL: ipc event cap ($_N)"; PASS=0; fi
# handler timeout: temp slow handler (sleeps 12s > 10s handler timeout)
printf '#!/bin/sh\nsleep 12\necho slow-done\n' > /etc/aira/ipc/handlers/slowtest
chmod +x /etc/aira/ipc/handlers/slowtest
_ST="$(date +%s 2>/dev/null || echo 0)"
_R="$(printf "AIRA1|ttime|0:root|slowtest|run|none|x\n" | timeout 15 nc -w 15 127.0.0.1 41234 2>/dev/null || true)"
_ET="$(date +%s 2>/dev/null || echo 0)"
rm -f /etc/aira/ipc/handlers/slowtest
if printf "%s" "$_R" | grep -q "timeout"; then echo "GUEST-TEST OK: ipc handler timeout";
else echo "GUEST-TEST FAIL: ipc handler timeout: $(printf "%s" "$_R" | cut -c1-100)"; PASS=0; fi
t "ipc ping after timeout" aira-ipc ping after-timeout
# service failure: kill syslog, bus must report failed, restart recovers
_SVCPID="$(cat /run/aira-services/syslog.pid 2>/dev/null)"
if [ -n "$_SVCPID" ]; then
  kill -9 "$_SVCPID" 2>/dev/null; sleep 0.5
  if aira-ipc call services status syslog 2>/dev/null | grep -q "failed"; then
    echo "GUEST-TEST OK: ipc reports crashed service as failed"
  else
    echo "GUEST-TEST FAIL: ipc crash not reported"; PASS=0
  fi
  t "ipc recover crashed service" aira-ipc call services restart syslog
else
  echo "GUEST-TEST FAIL: no syslog pid for crash test"; PASS=0
fi
# daemon failure + recovery
_IPCPID="$(cat /run/aira-services/ipc.pid 2>/dev/null)"
if [ -n "$_IPCPID" ]; then
  kill -9 "$_IPCPID" 2>/dev/null; sleep 0.5
  if aira-ipc ping 2>/dev/null; then echo "GUEST-TEST FAIL: ipc alive after kill"; PASS=0;
  else echo "GUEST-TEST OK: ipc unreachable after kill"; fi
  t "ipc daemon restart" /sbin/aira-init restart ipc
  sleep 1
  t "ipc ping after restart" aira-ipc ping revived
else
  echo "GUEST-TEST FAIL: no ipc pid"; PASS=0
fi
# real integration: aira status + doctor must use the bus
/usr/bin/aira status > /tmp/aira-status-ipc.out 2>&1
t_contains "aira status via IPC" /tmp/aira-status-ipc.out "via IPC bus"
/usr/bin/aira doctor > /tmp/aira-doctor.out 2>&1 && echo "GUEST-TEST OK: aira doctor" || { echo "GUEST-TEST FAIL: aira doctor"; cat /tmp/aira-doctor.out 2>&1; PASS=0; }
# aira-doctor (C7) reports "area check STATUS detail" in a column-aligned
# layout, so assertions must tolerate the padding between fields.
t_contains "doctor ipc bus PASS" /tmp/aira-doctor.out "ipc  *bus  *PASS"
t_contains "doctor kernel release" /tmp/aira-doctor.out "kernel  *release  *PASS"
t_contains "doctor storage df" /tmp/aira-doctor.out "storage  *df  *PASS"
/usr/bin/aira-doctor --json > /tmp/aira-doctor.json 2>&1
t_contains "doctor json" /tmp/aira-doctor.json '"summary"'
t_contains "doctor json checks" /tmp/aira-doctor.json '"checks"'

echo "--- storage ---"
df > /tmp/df.out 2>&1 && echo "GUEST-TEST OK: df works" || { echo "GUEST-TEST FAIL: df"; PASS=0; }
if [ -b /dev/vda ]; then
  mkdir -p /persist
  if mount 2>/dev/null | grep -q " /persist "; then
    echo "GUEST-TEST OK: /dev/vda mounted (/persist already mounted by /init)"
  elif mount -t ext4 /dev/vda /persist 2>/dev/null; then
    echo "GUEST-TEST OK: /dev/vda mounted"
  else
    echo "GUEST-TEST INFO: /dev/vda present but mount failed (may need mkfs)"
  fi
  if mount 2>/dev/null | grep -q " /persist "; then
    if [ -f /persist/autotest-marker ]; then
      echo "GUEST-TEST OK: persist-exists from previous boot: $(cat /persist/autotest-marker)"
    else
      echo "GUEST-TEST INFO: no previous persist marker (first boot with this disk)"
    fi
    echo "persist-autotest-$(date +%s 2>/dev/null || echo manual)" > /persist/autotest-marker 2>/dev/null && echo "GUEST-TEST OK: persist write" || { echo "GUEST-TEST FAIL: persist write"; PASS=0; }
    cat /persist/autotest-marker 2>/dev/null
    sync
  fi
else
  echo "GUEST-TEST INFO: no /dev/vda (boot with --drive for persistence test)"
fi

echo "--- packages ---"
mkdir -p /tmp/pkgtest/usr/share/aira
cat > /tmp/pkgtest/PKGINFO <<'EOF'
NAME="hello-aira"
VERSION="1.0"
DESC="test package"
DEPS=""
EOF
echo "hello aira" > /tmp/pkgtest/usr/share/aira/hello.txt
t "airapkg build" airapkg build /tmp/pkgtest /tmp/hello-aira.apkg
cp -f /tmp/hello-aira.apkg /var/lib/airapkg/repo/ 2>/dev/null || true
t "airapkg search" airapkg search hello
t "airapkg info" airapkg info hello-aira
t "airapkg update-check" airapkg update-check
t "airapkg install" airapkg install /tmp/hello-aira.apkg
t_contains "package file installed" /tmp/t.out "hello-aira"
[ -f /usr/share/aira/hello.txt ] && echo "GUEST-TEST OK: payload present" || { echo "GUEST-TEST FAIL: payload missing"; PASS=0; }
t "airapkg verify" airapkg verify hello-aira
t "airapkg remove" airapkg remove hello-aira
[ ! -f /usr/share/aira/hello.txt ] && echo "GUEST-TEST OK: payload cleaned" || { echo "GUEST-TEST FAIL: payload not cleaned"; PASS=0; }
rm -f /var/lib/airapkg/repo/hello-aira.apkg
if airapkg install /tmp/does-not-exist.apkg 2>/dev/null; then echo "GUEST-TEST FAIL: invalid package accepted"; PASS=0;
else echo "GUEST-TEST OK: invalid package rejected"; fi
echo "corrupt-data" > /tmp/corrupt.apkg
if airapkg install /tmp/corrupt.apkg 2>/dev/null; then echo "GUEST-TEST FAIL: corrupt package accepted"; PASS=0;
else echo "GUEST-TEST OK: corrupt package rejected"; fi
rm -f /tmp/corrupt.apkg
# malicious archives (must be sandboxed)
mkdir -p /tmp/mal-abs/usr/share
printf 'NAME="mal-abs"\nVERSION="1.0"\nDESC="x"\nDEPS=""\n' > /tmp/mal-abs/PKGINFO
echo "evil" > /tmp/mal-abs/usr/share/evil.txt
# craft absolute-path archive (bypass airapkg build)
tar -czf /tmp/mal-abs.apkg -C / -tmp/mal-abs/usr/share/evil.txt 2>/dev/null || true
# Instead craft via explicit absolute member using python if available, else simulate via tar transform
# Simpler: test the validation directly by crafting a tar with ../
mkdir -p /tmp/mal-trav
printf 'NAME="mal-trav"\nVERSION="1.0"\nDESC="x"\nDEPS=""\n' > /tmp/mal-trav/PKGINFO
mkdir -p /tmp/mal-trav/payload
echo "evil" > /tmp/mal-trav/payload/evil.txt
# Create tar with traversal member
tar -czf /tmp/mal-trav.apkg -C /tmp/mal-trav payload/evil.txt --transform 's,payload/,../,' 2>/dev/null || tar -czf /tmp/mal-trav.apkg -C /tmp payload 2>/dev/null || true
if airapkg install /tmp/mal-trav.apkg 2>/dev/null; then echo "GUEST-TEST FAIL: traversal accepted"; PASS=0;
else echo "GUEST-TEST OK: traversal rejected"; fi
rm -rf /tmp/mal-abs /tmp/mal-abs.apkg /tmp/mal-trav /tmp/mal-trav.apkg
# symlink escape: create pkg with symlink
mkdir -p /tmp/mal-link
printf 'NAME="mal-link"\nVERSION="1.0"\nDESC="x"\nDEPS=""\n' > /tmp/mal-link/PKGINFO
ln -sf /etc/passwd /tmp/mal-link/evil-link 2>/dev/null || true
tar -czf /tmp/mal-link.apkg -C /tmp/mal-link . 2>/dev/null || true
if airapkg install /tmp/mal-link.apkg 2>/dev/null; then echo "GUEST-TEST FAIL: symlink accepted"; PASS=0;
else echo "GUEST-TEST OK: symlink rejected"; fi
rm -rf /tmp/mal-link /tmp/mal-link.apkg
echo "--- rollback ---"
mkdir -p /tmp/rbtest/usr/share/aira
printf 'NAME="rbtest"\nVERSION="2.0"\nDESC="rollback test"\nDEPS=""\n' > /tmp/rbtest/PKGINFO
echo "v1-content" > /usr/share/aira/rb.txt
echo "v2-content" > /tmp/rbtest/usr/share/aira/rb.txt
t "rollback pkg build" airapkg build /tmp/rbtest /tmp/rbtest.apkg
t "rollback pkg install" airapkg install /tmp/rbtest.apkg
[ "$(cat /usr/share/aira/rb.txt 2>/dev/null)" = "v2-content" ] && echo "GUEST-TEST OK: v2 installed" || { echo "GUEST-TEST FAIL: v2 content"; PASS=0; }
t "rollback restore" airapkg rollback rbtest
[ "$(cat /usr/share/aira/rb.txt 2>/dev/null)" = "v1-content" ] && echo "GUEST-TEST OK: rollback restored v1" || { echo "GUEST-TEST FAIL: rollback content"; PASS=0; }
t "rollback pkg remove" airapkg remove rbtest
rm -rf /tmp/rbtest /tmp/rbtest.apkg /usr/share/aira/rb.txt
mkdir -p /tmp/deptest
printf 'NAME="deptest"\nVERSION="1.0"\nDESC="dep test"\nDEPS="missing-dep-xyz"\n' > /tmp/deptest/PKGINFO
airapkg build /tmp/deptest /tmp/deptest.apkg >/dev/null 2>&1
if airapkg install /tmp/deptest.apkg 2>&1 | grep -q "WARN: dependency"; then
  echo "GUEST-TEST OK: missing dep warns"
else
  echo "GUEST-TEST FAIL: missing dep warning"; PASS=0
fi
airapkg remove deptest >/dev/null 2>&1
rm -rf /tmp/deptest /tmp/deptest.apkg
echo "--- sample app (dev workflow) ---"
SAMPLE_APKG=""
for cand in /var/lib/airapkg/repo/hello-aira-1.0.apkg /persist/var/lib/airapkg/repo/hello-aira-1.0.apkg; do
  if [ -f "$cand" ]; then SAMPLE_APKG="$cand"; break; fi
done
if [ -n "$SAMPLE_APKG" ]; then
  echo "sample apkg: $SAMPLE_APKG"
  t "sample install" airapkg install "$SAMPLE_APKG"
  if [ "$(/usr/share/aira-samples/hello-aira 2>/dev/null)" = "hello from AiraOS-Octave sample v1.0" ]; then
    echo "GUEST-TEST OK: sample executes with exact output"
  else
    echo "GUEST-TEST FAIL: sample output"; /usr/share/aira-samples/hello-aira 2>&1; PASS=0
  fi
  t "sample remove" airapkg remove hello-aira
else
  echo "GUEST-TEST INFO: sample .apkg not in repo image (dev image only)"
fi

echo "--- gui (if requested) ---"
if grep -q "aira_guitest=1" /proc/cmdline 2>/dev/null; then
  # GUI lives in /persist (rootfs.img); extend PATH/LD so Xvfb/jwm run
  if [ -d /persist/usr/bin ]; then
    export PATH=/persist/usr/bin:/persist/bin:/persist/sbin:$PATH
    export LD_LIBRARY_PATH=/persist/usr/lib/x86_64-linux-gnu:/persist/lib/x86_64-linux-gnu:/persist/usr/lib:$LD_LIBRARY_PATH
    echo "GUI-TEST: using /persist GUI stack"
    if [ -x /persist/usr/bin/aira-gui-test ]; then
      if /persist/usr/bin/aira-gui-test 2>&1; then echo "GUEST-TEST OK: gui";
      else echo "GUEST-TEST FAIL: gui"; PASS=0; fi
    elif [ -x /usr/bin/aira-gui-test ]; then
      if /usr/bin/aira-gui-test 2>&1; then echo "GUEST-TEST OK: gui";
      else echo "GUEST-TEST FAIL: gui"; PASS=0; fi
    else
      echo "GUEST-TEST FAIL: aira-gui-test not found (build-gui.sh missing?)"; PASS=0
    fi
  else
    echo "GUEST-TEST FAIL: /persist/usr/bin missing (boot with --drive aira-rootfs.img after build-gui)"; PASS=0
  fi
else
  echo "GUI-TEST: skipped (no aira_guitest=1)"
fi

if [ "$PASS" = "1" ]; then echo "===== GUEST AUTOTEST PASS =====";
else echo "===== GUEST AUTOTEST FAIL ====="; fi
echo "powering off"
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo "halt"
sleep 5
