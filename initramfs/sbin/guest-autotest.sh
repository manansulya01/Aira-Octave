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
t "service restart net" /sbin/aira-init restart net
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

echo "--- platform ---"
t "aira platform" /usr/bin/aira platform
/usr/bin/aira platform > /tmp/aira-platform.out 2>&1
t_contains "platform cpu" /tmp/aira-platform.out "model name"
t_contains "platform pci" /tmp/aira-platform.out "vendor="
t_contains "platform interrupts" /tmp/aira-platform.out "CPU0"
echo "--- platform listing (evidence) ---"
head -n 30 /tmp/aira-platform.out

echo "--- networking ---"
ip link set lo up 2>/dev/null
ip addr add 127.0.0.1/8 dev lo 2>/dev/null
t "ip link lo" ip link show lo
t "ping loopback" ping -c1 -W2 127.0.0.1
ip addr show eth0 2>/dev/null && echo "GUEST-TEST INFO: eth0 present" || echo "GUEST-TEST INFO: no eth0 (ok without --net)"

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
