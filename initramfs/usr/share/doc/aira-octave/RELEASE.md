# Release 0.1.0

## Artifacts (release/)
- aira-octave-0.1.0.tar.gz (112M) + .iso (541M, grub2) + boot/bzImage + boot/initramfs.cpio + aira-rootfs.img (512M ext4) + .sha256 + RELEASE_NOTES.txt
- Build: scripts/build-release.sh 0.1.0. Tested: test-iso.sh PASS (grub→kernel→userspace).

## Reproduce
1. cp configs/airaos-octave-x86_64.config linux-7.2.2/.config (or use release kernel-config.txt)
2. build-kernel.sh (expect 15M GZIP bzImage) — incremental if tree built
3. build-initramfs.sh (expect 2.2M, /init + busybox)
4. build-gui.sh + build-rootfs.sh 512 (expect 512M ext4, Xvfb/JWM)
5. test-all.sh (expect PASS all 6) + test-iso.sh
6. build-release.sh 0.1.0

## Checksums
See release/aira-octave-0.1.0.sha256.
