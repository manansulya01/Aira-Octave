# Hardware Capability Matrix (config + QEMU evidence, 1.0.0)

Columns: COMPONENT | CONFIGURED | BOOT-TESTED | QEMU-TESTED | PHYSICAL | STATUS | LIMITATION

- CPU x86_64 / SMP=y NR_CPUS=64 | y | y | y(1 vCPU) | UNTESTED | QEMU VERIFIED | multi-vCPU never booted
- RAM/paging/SLUB | y | y | y(476M) | UNTESTED | QEMU VERIFIED | no pressure test
- Storage ATA/PIIX/SCSI/sr | y | y | y(sr0) | UNTESTED | QEMU VERIFIED | -
- Storage AHCI/SD | y | n (no device) | n | UNTESTED | EXPECTED | no SATA disk attached in tests
- NVMe block | n (BLK_DEV_NVME off; NVMEM framework only) | n | n | UNTESTED | UNSUPPORTED | config-verified absent
- virtio-blk/net | y | y | y | UNTESTED | QEMU VERIFIED | -
- virtio-gpu (DRM_VIRTIO_GPU) | y | n | n (Xvfb used) | UNTESTED | EXPECTED | /dev/dri path never exercised
- virtio-input | y | n | n (XTEST used) | UNTESTED | EXPECTED | no evdev event test
- e1000/e1000e | y | y | y | UNTESTED | QEMU VERIFIED | -
- i8042/kbd/mouse, evdev | y | y | y(detect) | UNTESTED | QEMU VERIFIED | no physical key events
- Serial 8250 console | y | y | y | UNTESTED | QEMU VERIFIED | primary evidence channel
- Display Bochs VGA | n (driver off) | n | n | UNTESTED | UNSUPPORTED | by design; use virtio-gpu
- Framebuffer (any) | n | n | n | UNTESTED | UNSUPPORTED | serial-only console
- USB/xHCI/storage | y | n | n | UNTESTED | UNTESTED | drivers present, zero evidence
- Audio HDA | y | n | n | UNTESTED | UNTESTED | drivers present, zero evidence
- Ethernet | y | y | y | UNTESTED | QEMU VERIFIED | -
- Wi-Fi | vendor symbols on, IWLWIFI off (no verified driver) | n | n | UNTESTED | UNTESTED | no evidence of a working driver
- Bluetooth | n (no BT symbols) | n | n | UNTESTED | UNSUPPORTED | config-verified absent
- ACPI/S5 | y | y | y(poweroff every run) | UNTESTED | QEMU VERIFIED | -
- PCI/MSI | y | y | y(6 devs) | UNTESTED | QEMU VERIFIED | -

Rule applied: driver presence ≠ support. Anything without a boot/test log stays
EXPECTED at best; physical column is UNTESTED everywhere (no HW access in env).
