# AiraOS-Octave Boot Guide

## Text boot (verified, reproducible)
```bash
bash scripts/boot-qemu.sh --mem 512M --timeout 30 --log logs/boot.log
bash scripts/test-kernel.sh   # automated PASS/FAIL
```
QEMU: `qemu-system-x86_64 -kernel linux-7.2.2/arch/x86/boot/bzImage
-initrd initramfs.cpio -append "console=ttyS0 rdinit=/init loglevel=7"
-m 512M -nographic -no-reboot`

Expected serial markers:
- `Linux version 7.2.2`
- `Run /init as init process`
- `AiraOS userspace ready`
- No `Kernel panic`, no `Oops`.

QEMU exit 124 (timeout kill) is EXPECTED — guest idles at shell.
`test-kernel.sh` treats 124 + markers as PASS.

## Boot with persistent disk
```bash
bash scripts/boot-qemu.sh --drive aira-rootfs.img --log logs/boot-persist.log
# in guest: mount -t ext4 /dev/vda /persist; echo hi > /persist/test; reboot
```

## Boot with network (user-mode)
```bash
bash scripts/boot-qemu.sh --net user --log logs/boot-net.log
# in guest: ip addr; udhcpc -i eth0; ping -c1 10.0.2.2
```
Kernel has E1000 + VIRTIO_NET. Default script uses e1000 (QEMU default NIC);
`--net user` adds virtio-net PCI device.

## Boot with graphics (virtio-gpu)
```bash
bash scripts/boot-qemu.sh --gpu virtio --mem 1G --log logs/boot-gui.log
# in guest: ls /dev/dri; aira-desktop --check; startx /usr/bin/aira-session
```
Kernel has DRM=y + VIRTIO_GPU=y + VIRTIO_INPUT=y. Default std VGA (Bochs
1234:1111) has NO driver (BOCHS DRM off by design to avoid rebuild);
use `--gpu virtio` for GUI. Text boot stays on std VGA + serial.

## Recovery
If GUI fails, text serial shell remains. `/init` always leaves
`/bin/sh` on console. See docs/TROUBLESHOOTING.md.
Boot params: `rdinit=/init` required; `loglevel=7` for debug.
