# Install / Run AiraOS-Octave 1.5.0

## Try it without changing a disk

Build the release from the repository first (see [BUILD.md](BUILD.md)). The
release directory should contain `boot/bzImage`, `boot/initramfs.cpio`, and
`aira-rootfs.img`.

Boot the release ISO in QEMU:

```sh
qemu-system-x86_64 -cdrom release/aira-octave-1.5.0.iso -boot d \
  -m 1024M -serial stdio -monitor none -no-reboot
```

To boot the kernel/initramfs directly with the desktop filesystem attached:

```sh
qemu-system-x86_64 \
  -kernel release/aira-octave-1.5.0/boot/bzImage \
  -initrd release/aira-octave-1.5.0/boot/initramfs.cpio \
  -append "console=ttyS0 rdinit=/init loglevel=7" \
  -drive file=release/aira-octave-1.5.0/aira-rootfs.img,if=virtio,format=raw \
  -m 1024M -nographic -no-reboot
```

## Install to a separate BIOS/MBR disk

The host-side installer is `scripts/install-to-disk.sh`. It requires Linux root
privileges and tools including `sfdisk`, `mkfs.ext4`, `mount`, and
`grub-install`. It installs the release root filesystem, kernel, and initramfs
to a single ext4 partition and installs the legacy BIOS GRUB bootloader.

**Warning: installation erases the entire selected disk. Back up the target
first. Do not select your system disk.** Inspect the target device carefully;
use a disposable test disk or VM disk while validating the installer.

```sh
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS,MODEL
sudo scripts/install-to-disk.sh \
  --target /dev/sdX \
  --release-dir release/aira-octave-1.5.0
```

Replace `/dev/sdX` with the intended **whole disk**, not a partition. The
installer requires you to type the exact erase confirmation. Unattended use is
blocked unless both `--yes` and `--allow-erase` are explicitly supplied.

This installer currently targets **legacy BIOS/MBR only**. UEFI installation,
Secure Boot, and unattended installation are not yet supported. Do not treat a
successful file-copy step as hardware certification; boot the installed disk
and verify networking, persistence, recovery, and desktop behavior on the
actual target platform.

The in-guest `aira-install` command is a legacy path and now fails before
partitioning if its required boot tools or source artifacts are unavailable.
Use the host-side installer above for the current supported installation path.

## Build and verification

See [BUILD.md](BUILD.md) and [TESTING.md](TESTING.md). The full GitHub Actions
workflow builds the kernel, initramfs, desktop filesystem, and release ISO, then
runs kernel/userspace, GUI, network, recovery, persistence, support-bundle,
installer/update safety, release-guard, and ISO-boot checks. Check the workflow
result before treating a release as verified.
