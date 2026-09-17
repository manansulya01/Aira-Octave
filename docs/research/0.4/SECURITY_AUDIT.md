# 0.4 Security Audit (evidence-based)

Evidence: logs/final-completion/services/services-20260917-122355.log
(security section + privileged-process listing).

## Users / ownership — VERIFIED
- root (0) + aira (1000) in /etc/passwd; groups in /etc/group.
- /root is 700 (guest-asserted); /home/aira owned 1000:1000.
- DAC boundary guest-tested: aira denied /root write, allowed own home.

## Privileged execution — VERIFIED mechanism, documented scope
- Services declare USER= (default root); supervisor launches non-root via
  `su -s /bin/sh USER -c` with ownership-proven test (marker file UID 1000).
- Current core services (syslog/klog/net/persist) run as root — necessary:
  syslog/klog read kernel logs, net configures interfaces, persist mounts.
- No setuid/setgid files in /bin /sbin /usr/bin (guest-scanned).
- No TCP listeners by default (guest-scanned via netstat -ltn).

## Residual risks (honest)
- Desktop/Xvfb/JWM run as root in headless test; user-session separation future work.
- Serial console yields root shell (physical/QEMU access = root by design; recovery requirement).
- No firewall rules, no disk encryption, no secure-boot signing.

## 0.4 changes
- /init: chmod 700 /root (was 755 default).
- Guest coverage: /root perms, setuid scan, listener scan, privileged-process dump.
