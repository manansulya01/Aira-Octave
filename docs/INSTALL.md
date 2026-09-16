# Install / Run AiraOS-Octave 0.1.0

## From release (recommended)
1. Get `release/aira-octave-0.1.0.tar.gz` (+ .sha256). Verify: `sha256sum -c`.
2. Extract. You need: `boot/bzImage`, `boot/initramfs.cpio`, `aira-rootfs.img`, qemu-system-x86_64.
3. Text boot: `qemu-system-x86_64 -kernel boot/bzImage -initrd boot/initramfs.cpio -append "console=ttyS0 rdinit=/init loglevel=7" -m 512M -nographic -no-reboot`
4. With disk+GUI: add `-drive file=aira-rootfs.img,if=virtio,format=raw -m 1G`, then in guest `aira-session --headless` (test) or `aira-session` (interactive with display).
5. ISO: `qemu-system-x86_64 -cdrom aira-octave-0.1.0.iso -boot d -m 512M -nographic -no-reboot`.

## From source
See BUILD.md (canonical config, build-kernel/initramfs/rootfs/gui, test-all.sh).
