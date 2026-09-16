# Hardware Compatibility (0.2.0)

| Device | QEMU | Physical HW | Notes |
|---|---|---|---|
| x86_64 CPU/SMP | VERIFIED IN QEMU | UNTESTED | 1 vCPU TCG; SMP options in config |
| Serial 16550A | VERIFIED IN QEMU | UNTESTED | primary console |
| PCI/i440FX, ACPI | VERIFIED IN QEMU | UNTESTED | enumerated in boot log |
| e1000 / virtio-net | VERIFIED IN QEMU | UNTESTED | DHCP via user-net |
| virtio-blk ext4 persist | VERIFIED IN QEMU | UNTESTED | 2-boot test |
| ata_piix CD-ROM | VERIFIED IN QEMU | UNTESTED | sr0 present |
| i8042 kbd/mouse | VERIFIED IN QEMU | UNTESTED | X input via XTEST headless |
| virtio-gpu DRM | EXPECTED | UNTESTED | driver built-in; X tested via Xvfb instead |
| virtio-input | EXPECTED | UNTESTED | driver built-in; not exercised |
| Bochs VGA | UNSUPPORTED | N/A | no driver (use virtio-gpu) |
| USB/audio/PM | UNTESTED | UNTESTED | stock Linux drivers, no tests |

No physical-hardware claims. Text+GUI stacks verified under QEMU TCG on WSL.
