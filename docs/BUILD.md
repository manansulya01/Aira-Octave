# AiraOS-Octave Build Guide
Version: 0.1.0 (Linux 7.2.2 foundation, 2026-09-15)

## Canonical configuration
- `configs/airaos-octave-x86_64.config` — exact copy of working
  `linux-7.2.2/.config` (GZIP, PREEMPT_DYNAMIC, 5473 lines, sha256
  `80a13a5f95bb050c70e7b44b34f60a37450e9139371828208051455e1e2e6fcd`).
- Legacy `configs/airaos-x86_64.config` (2477 lines, XZ) is NOT canonical;
  kept for history only. Do not build release from it.
- Root `.config` (98-byte fragment disabling PRINTK/SATA) is a leftover
  experiment artifact; do not use. Release builds use configs/airaos-octave-x86_64.config.

## Dependencies (WSL Ubuntu, x86_64)
gcc 15.2.0, binutils 2.46 (ld), make, flex, bison, libssl-dev, libelf-dev,
bc, cpio, qemu-system-x86 10.2.1, e2fsprogs (mkfs.ext4), dosfstools (optional).

## Reproducible kernel build
```bash
cp configs/airaos-octave-x86_64.config linux-7.2.2/.config
bash scripts/build-kernel.sh
# outputs: linux-7.2.2/arch/x86/boot/bzImage (expect ~15M GZIP, syssize 0xe5640)
```
`build-kernel.sh` records timestamps, versions, commands, saves logs to
`logs/final-completion/build/`, verifies bzImage via `file` (must show
`gzip compressed`, `version 7.2.2`). Incremental rebuild is fast when tree
is already built; clean rebuild takes much longer (avoid unless needed).

## Initramfs build
```bash
bash scripts/build-initramfs.sh
# outputs: initramfs.cpio (expect ~2.1M, contains /init + BusyBox)
```
Reproducible: builds cpio from `initramfs/` source (newc format, no xattrs
unless supported). Verifies `/init` executable + `bin/busybox` + `bin/sh`
present via `cpio -t`. Does NOT overwrite working initramfs.cpio unless
new image passes content checks; keeps `.bak`.

## Rootfs (persistent) build
```bash
bash scripts/build-rootfs.sh
# outputs: aira-rootfs.img (ext4, 256M, contains /etc/aira, /home/aira, /var/log/airaos, GUI)
```
Uses `mkfs.ext4 -d` overlay from `rootfs/` staging dir (created by script).
If `-d` unsupported, falls back to genext2fs-style mount-loop (requires sudo;
script prefers fakeroot-free `mkfs.ext4 -d`).

## Release
```bash
bash scripts/test-all.sh        # must PASS
bash scripts/build-release.sh   # kernel+initramfs+rootfs+iso+sha256+notes
```
See docs/RELEASE.md.
