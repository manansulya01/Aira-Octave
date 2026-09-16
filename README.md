# AiraOS-Octave 0.1.0

Bootable x86_64 OS: Linux 7.2.2 + AiraOS userspace + services + persistent ext4 + networking + package manager + X11/JWM desktop + apps + tests + release.

## Quick start
- Build: `bash scripts/build-kernel.sh`, `bash scripts/build-initramfs.sh`, `bash scripts/build-gui.sh`, `bash scripts/build-rootfs.sh 512`
- Boot text: `bash scripts/boot-qemu.sh --mem 512M --timeout 30 --log logs/boot.log`
- Boot GUI/persist: add `--drive aira-rootfs.img --mem 1G`, in guest run `/persist/usr/bin/aira-session`
- Test: `bash scripts/test-all.sh` (kernel/userspace/services/storage/network/gui)
- Release: `bash scripts/build-release.sh 0.1.0`, boot ISO via `bash scripts/test-iso.sh`

## What's inside
- Kernel 7.2.2 GZIP/SMP/PREEMPT_DYNAMIC, virtio (blk/net/gpu/input), e1000, ext4, DRM.
- Userspace: BusyBox, /init, aira CLI, airapkg, service manager, users (root+aira), diagnostics.
- Desktop: Xvfb/Xorg + JWM (Aira menu), xterm, mc file manager, settings, sysinfo, about.

## Hardware
QEMU verified (see HARDWARE_SUPPORT.md). Real HW untested.

## Limitations
- Services/GUI run as root; no login; no firewall/encryption (see SECURITY.md).
- File-manager/settings interactive flows partially verified headless (wrappers+backends tested, click-through manual).
- See docs/research/FINAL_COMPLETION_REPORT.md for full status.
