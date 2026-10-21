# Security (0.1.0 audit)

## Tested
- Users: root + aira (1000) in /etc/passwd/group; /home/aira owned 1000:1000.
- DAC: guest test proves aira cannot write /root, can write own home. (test-services log)
- No setuid binaries in initramfs (BusyBox applets, no suid bit set at build).
- Services run as root (documented limitation; no privilege drop in v1 supervisor).
- No network listeners by default (no httpd/telnet started; udhcpc client only).
- Kernel: PREEMPT_DYNAMIC, ASLR/mmap randomization per Linux defaults, no custom LSM.

## Limitations (honest)
- Services as root; GUI (Xvfb/JWM) as root; no user-session separation in v1.
- No firewall rules shipped; no secure-boot signing; no disk encryption.
- Passwords: locked/disabled (no login testing); serial console gives root shell (physical/QEMU access = root, by design for v1 recovery).
- Remaining work: drop privileges for syslog/net/gui, add login, nftables baseline, Secure Boot, and a trusted signed-update design.
- Package signing is not implemented. The former `airapkg sign` / `verify-sig` commands only used SHA-256 checksums, which do not authenticate a publisher; they now fail closed. Treat the local package repository as trusted input.
