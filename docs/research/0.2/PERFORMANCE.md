# Performance 0.2 (QEMU TCG on WSL)

## Sizes
- bzImage 15M, vmlinux 52M, initramfs 2.2M (unchanged from 0.1.0).
- rootfs staging 277M (142 debs), image 512M ext4.
- ISO ~541M+, tarball ~112M+ (0.2.0 figures in release notes at build time).

## Times (serial timestamps, TCG — slower than KVM/HW)
- Kernel → userspace ready: ~3s (text).
- Services (4): <1s. GUI desktop ready: ~9–13s.
- xterm launch ~2s; xwd screenshot 3.1MB.

## Notes
No blind optimization. Known waste: LLVM30M+gallium11M pulled by Xvfb GL linkage
(future: Xvfb without GL). Idle CPU unmeasured under TCG.
