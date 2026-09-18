# 0.9 Performance (QEMU TCG on WSL — slower than KVM/HW, honest figures)

## Sizes (VERIFIED: ls/sha256)
- bzImage 15M, vmlinux 52M, initramfs.cpio 2.2M (95 applets + aira stack).
- rootfs staging ~277M (142 debs), aira-rootfs.img 512M ext4.
- Release ISO ~541M, tarball ~112M (0.2.0 figures; 1.0.0 re-measured at release).

## Times (VERIFIED: serial timestamps)
- SeaBIOS → Linux version: ~1s. Run /init: ~2.7s. Userspace ready: ~3s (512M text).
- 4 services: <1s. Xvfb+JWM desktop ready: ~9–13s.
- xterm launch ~2s (TCG). xwd 1024x768 screenshot 3.1MB.

## Memory (VERIFIED: /proc/meminfo in boot logs)
- MemTotal ~476MB of 512M VM. No OOM events in any test boot.

## CPU (UNMEASURED under TCG — host-shared, not meaningful)
- No per-boot CPU benchmark claimed.

## Issues found by measurement
- None blocking. Known waste (not fixed — documented):
  LLVM30M+gallium11M pulled by Xvfb GL linkage; DejaVu+fonts required for JWM.
  Future: Xvfb without GL, slimmer WM font path.
