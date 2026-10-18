# Hardware Support (0.1.0)

| Device | QEMU | Real HW | Notes |
|---|---|---|---|
| Serial (ttyS0) | VERIFIED | UNTESTED | console=ttyS0, boot logs captured |
| PCI/i440FX+ACPI | VERIFIED | UNTESTED | boot log enumerates |
| e1000 NIC | VERIFIED | UNTESTED | eth0 appears; DHCP via user-net tested |
| virtio-net | VERIFIED | UNTESTED | --net user tested |
| virtio-blk (/dev/vda) | VERIFIED | UNTESTED | ext4 persistence 2-boot verified |
| ata_piix CD-ROM | VERIFIED | UNTESTED | sr0 in boot log |
| i8042 kbd/mouse | VERIFIED | UNTESTED | AT kbd + PS/2 mouse in boot log; X input via XTEST (headless) |
| virtio-gpu DRM | VERIFIED | UNTESTED | driver built-in (VIRTIO_GPU=y); Xorg modesetting 1024x768@60 depth 24 on /dev/dri/card0, JWM + xterm + Aira apps verified visible via screendump + xwd (see scripts/boot-gui.sh) |
| virtio-input | VERIFIED | UNTESTED | driver built-in; Xorg libinput driver staged; cold-plugged virtio keyboard/mouse enumerated by Xorg |
| Bochs VGA | UNSUPPORTED | N/A | no BOCHS DRM (by design, use virtio-gpu for real Xorg) |
| USB/audio/PM | UNTESTED | UNTESTED | drivers present per config; no tests |

Real x86_64 hardware: UNTESTED (no physical test env). Do not claim HW support.
