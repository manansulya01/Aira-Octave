# Performance Audit (0.1.0, QEMU TCG on WSL, 512M-1G)

## Sizes (VERIFIED, ls/sha256)
- bzImage 15M (e198875...), vmlinux 52M, System.map (if present)
- initramfs.cpio 2.2M (95 busybox applets + aira stack)
- rootfs staging 277M (142 debs incl. llvm30M+gallium11M+fonts6M), image 512M ext4
- ISO 541M, tarball 112M

## Boot time (VERIFIED, serial timestamps)
- SeaBIOS→Linux version: ~1s; Run /init: ~2.7s; userspace ready: ~3s (text, 512M).
- Services (4): <1s. GUI (Xvfb+JWM): desktop ready ~9-13s after boot (TCG slow).

## Runtime (PARTIALLY VERIFIED)
- MemTotal 476MB (512M VM). Idle CPU: UNMEASURED under TCG (host-dependent).
- xterm launch ~2s, screenshot (xwd 1024x768x24) 3.1MB.

## Notes
No premature optimization. Obvious waste: llvm30M+gallium11M for Xvfb software GL (could use Xvfb without GL in future). No regressions vs Aug30 baseline (same bzImage characteristics).
