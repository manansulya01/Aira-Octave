# AiraOS-Octave 0.2 Baseline (0.1.0 known-good)
Date: 2026-09-16
HEAD: 0664b7490 (feat-gui-release-docs-final-reports)
Prior: ac065c86b (userspace/services), abfd35f4c (infra/canonical config)

## Fingerprint (verified 2026-09-16)
- bzImage: e198875cf6eeb1ea5eaffec281ebb18f799596769c41d71677fb459f1457cb31 (15M, 7.2.2 #4 GZIP PREEMPT_DYNAMIC)
- initramfs.cpio: 92cfb133a591ea70b00e596410e5bb7f2c8face6ce075a68dcb0318350edc697 (2.2M)
- linux-7.2.2/.config: 80a13a5f95bb050c70e7b44b34f60a37450e9139371828208051455e1e2e6fcd (== configs/airaos-octave-x86_64.config)
- aira-rootfs.img: 18221939fa2d05f5f486b00e5e6f88d21a952deee89e8b45cef7af4510c8bd46 (512M ext4)
- release/: 0.1.0.tar.gz 878101bb..., 0.1.0.iso f060a268... (both boot-tested)
- Toolchain: gcc 15.2.0, ld 2.46, qemu 10.2.1, x86_64.
- Working tree matches release artifacts exactly (kernel+initramfs+rootfs).

## Provenance
- Kernel source: unmodified this mission cycle (git shows no linux-7.2.2 modifications).
- initramfs.cpio: rebuilt from initramfs/ source (tracked) — shows as `M` (tracked binary).
- Untracked (preserved, not deleted): .config fragment, config_diff_*.txt, docs/research/2026-09-*, logs/*, release/.
- Ignored by design: aira-rootfs.img, release ISOs/tarballs, rootfs/ staging, debs, *.log.

## Reproducibility
- scripts/test-all.sh PASS (6/6) on this tree; 3x consecutive test-kernel.sh PASS; test-iso.sh PASS.
- Rebuild path: build-kernel.sh (incremental) + build-initramfs.sh + build-gui.sh + build-rootfs.sh 512 + test-all.sh + build-release.sh.

## Rule
If any 0.2 change breaks test-kernel.sh markers, fix immediately before continuing.
