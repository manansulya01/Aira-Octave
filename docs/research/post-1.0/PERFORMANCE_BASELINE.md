# Post-1.0 Performance Baseline (QEMU TCG on WSL)

All MEASURED values from 2026-09-18 audit runs; TCG is slower than KVM/HW.

## MEASURED
- Boot: SeaBIOS→`Run /init` 2.07–2.12s; userspace banner ~0.5s later
  (baseline/qemu-baseline-20260918-112730.log).
- Initramfs unpack→shell: serial markers show full bring-up <4s guest uptime.
- Desktop ready: ~16s guest uptime from /init in gui-20260918-112858.log
  (includes autotest sections before GUI; Xvfb+JWM portion ESTIMATED 5–8s).
- Memory: MemTotal 476656 kB of 512M VM; zero OOM/panic across all runs.
- Artifact sizes: bzImage 15053824 B, initramfs 2246656 B, rootfs img 512MiB
  (staging ~277M), ISO 567275520 B.
- xwd screenshot: 3148907 B (1024x768x24, deterministic size).
- GUI suite wall time ≈ 150s budget, typically completes (QEMU_EXIT=0).

## ESTIMATED (prior data, same tree shape)
- Service boot <1s; xterm launch ~2s; package ops <1s.

## UNTESTED
- Idle CPU (TCG host-shared, meaningless); KVM/HW timings; boot with -smp 2;
  memory pressure/OOM behavior; network throughput; disk I/O benchmarks.

## Verdict
No measured bottleneck; no optimization justified. Known footprint cost:
LLVM30M+gallium11M via Xvfb GL linkage (documented, future slim-down).
