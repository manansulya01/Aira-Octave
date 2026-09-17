# 0.3 Hardware & Platform Report (evidence-based)

Source: guest `aira platform` output in logs/final-completion/services/services-20260917-122201.log
(lines ~438-475) + qemu boot logs. QEMU TCG on WSL, default (std VGA, e1000) config.

## Observed PCI (QEMU VERIFIED)
- 00:00.0 8086:1237 host bridge (i440FX)
- 00:01.0 8086:7000 ISA bridge (PIIX3)
- 00:01.1 8086:7010 IDE (ata_piix; sr0 CD-ROM in boot log)
- 00:01.3 8086:7113 ACPI bridge
- 00:02.0 1234:1111 VGA (Bochs std; NO driver — UNSUPPORTED by design)
- 00:03.0 8086:100e e1000 NIC (eth0, IRQ 11, UP)

## CPU/interrupts/timers (QEMU VERIFIED)
- QEMU Virtual CPU 2.5+, 2800MHz, 1 CPU (SMP kernel, single vCPU tested).
- IO-APIC routing: timer(0), i8042 kbd(1)/aux(12), ttyS0(4), rtc(8), acpi(9),
  eth0(11-fasteoi), ata(14/15). LOC timer interrupts ticking.

## VirtIO (QEMU VERIFIED where attached)
- No virtio devices in default boot (empty virtio section — honest output, not faked).
- virtio-blk: /dev/vda ext4 mount + 2-boot persistence (test-storage PASS).
- virtio-net: user-net link + DHCP path (test-network PASS).
- virtio-gpu/input: drivers built-in (VIRTIO_GPU/INPUT=y); GUI exercised via Xvfb
  instead (PARTIAL — /dev/dri path UNTESTED).

## Input/display (QEMU VERIFIED)
- i8042 KBD+AUX, AT keyboard, PS/2 mouse (dmesg). X input via XTEST headless.
- No /dev/dri or /dev/fb0 on std-VGA path (`aira platform` reports absence explicitly).

## Power/panic/logging
- ACPI S5 poweroff proven (every autotest ends with Power down).
- No panics/oops across all test boots. printk+serial+dmesg logging verified.

## Classification
- QEMU VERIFIED: CPU, interrupts, PCI, e1000, ata, i8042, serial, ACPI poweroff.
- QEMU VERIFIED (when attached): virtio-blk, virtio-net.
- EXPECTED (driver built-in, untested path): virtio-gpu/input, SMP>1.
- UNSUPPORTED: Bochs VGA driver. UNTESTED: all physical hardware.

## 0.3 changes
- New `aira platform` (real sysfs/dmesg/proc reads; reports absence instead of faking).
- Guest coverage: cpu/pci/interrupts asserts + full listing in logs.
