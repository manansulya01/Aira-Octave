# AiraOS-Octave Architecture (0.1.0)

## Stack
- Linux 7.2.2 x86_64 (SMP PREEMPT_DYNAMIC, GZIP) — scheduler, VM, VFS, syscalls, net, drivers. No kernel reimplementation.
- Initramfs root (BusyBox 1.37.0, ~95 applets) + /init → mounts, hostname, mdev, /persist, services, shell.
- Persistent ext4 disk (aira-rootfs.img, virtio-blk /dev/vda → /persist).
- Services: /sbin/aira-init (pidfiles, deps, boot order) — syslog, klog, net, persist.
- CLI: /usr/bin/aira (info/system/status/service/network/package/diagnose/update), /usr/bin/airapkg (.apkg tar.gz + PKGINFO, /var/lib/airapkg DB).
- GUI (on /persist): Xvfb/Xorg + JWM + xterm + mc + xmessage apps + aira-session. Headless-tested via Xvfb; interactive via virtio-gpu Xorg.
- Logs: /var/log/airaos/ (boot, dmesg, services, syslog).

## Boot flows
- Text: SeaBIOS → bzImage → initramfs /init → services → sh (serial). Verified.
- GUI: same + mount /persist → aira-session (Xvfb :99 + JWM + apps). Verified headless.
- ISO: grub2 → same kernel/initramfs. Verified.
- Recovery: /init always execs sh; GUI failure never blocks shell.

## What is Linux vs AiraOS
- Linux: everything kernel-level.
- AiraOS: /init, service manager, aira/airapkg, JWM session config, packaging, docs, tests, release.
