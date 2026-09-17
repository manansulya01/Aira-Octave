# 0.2-to-1.0 Baseline (authoritative 0.2.0, fingerprinted 2026-09-17)

## Source baseline
- HEAD: c710d4d0d "release: freeze verified 0.2.0 initramfs"
- Prior: 90e13f1e9 (feature matrix), a1997ef9b (0.2.0 showcase).
- Tree: clean except untracked historical logs + release/ (preserved, never added/deleted).

## Artifact fingerprint (all match release/aira-octave-0.2.0.sha256)
- bzImage: e198875cf6eeb1ea5eaffec281ebb18f799596769c41d71677fb459f1457cb31 (15M, 7.2.2 #4 GZIP PREEMPT_DYNAMIC)
- initramfs.cpio: 75320e46250d9325045a14195639f0c0da00c766545af1896fcc6f2fb5f47d73 (2.2M)
- linux-7.2.2/.config: 80a13a5f95bb050c70e7b44b34f60a37450e9139371828208051455e1e2e6fcd
- aira-rootfs.img: 32e695b3efc0ebde91e7f06df024b8ca66a9acdcc95cb4a45d16b9f9571de698 (512M ext4)
- 0.2.0.tar.gz: 4c48cba3fded9f4be07838194f24e1ed08fc6979c953c974261b52f50babbc08
- 0.2.0.iso: 41390fa96b1d3671a31481d8141c0f7b51c2b93c0692be3fd5a0276f33e1831c

## Toolchain
- gcc 15.2.0, ld 2.46, qemu 10.2.1, x86_64 host+target.

## Behavioral baseline
- docs/research/0.2/FEATURE_MATRIX.md (38 VERIFIED).
- Boot re-verified this session: test-kernel.sh PASS (12:19:02, all markers, no panic/oops).

## Rule
Any 0.3+ change breaking test-kernel markers gets fixed before continuing.
