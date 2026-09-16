# Troubleshooting

## Boot hangs at SeaBIOS / no Linux version
- You used wrong config (XZ minimal) or old bzImage. Use canonical: configs/airaos-octave-x86_64.config (GZIP, 15M, syssize 0xe5640). Rebuild via build-kernel.sh or restore release bzImage.

## No userspace ready
- Check rdinit=/init and console=ttyS0 in -append. Check initramfs.cpio contains /init (cpio -t).

## /usr/bin/aira not found in guest
- Shebangs must be #!/bin/sh (no bash in guest). Rebuild initramfs after editing.

## Xvfb dies / no socket
- See gui log diagnostics: missing lib (add to build-gui.sh PKGS, check-gui-libs.sh), missing xkbcomp symlink (session creates it), missing fonts (need fontconfig-config + DejaVu).

## JWM font errors / dies
- Need /etc/fonts + /usr/share/fonts symlinks (session creates) + fonts-dejavu-core + fontconfig-config in rootfs.

## Persist mount fails
- Image must be ext4 (build-rootfs.sh). QEMU needs -drive file=aira-rootfs.img,if=virtio,format=raw. Kernel has VIRTIO_BLK.

## Network no eth0
- Default QEMU NIC is e1000 (supported). For virtio-net add --net user (virtio-net-pci). DHCP may fail without user-net; loopback always works.
