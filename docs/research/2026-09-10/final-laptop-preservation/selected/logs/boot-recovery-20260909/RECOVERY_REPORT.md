# Boot Recovery Report - Experiment 1

## Objective
Verify if switching from XZ to GZIP compression resolves the boot regression.

## Experiment Details
- **Config**: Current K4 config + `CONFIG_KERNEL_GZIP=y` + `CONFIG_KERNEL_XZ=n`.
- **Build**: `make bzImage`.
- **Binary Size**: 3.0 MB.
- **Compression**: GZIP (confirmed by build logs).
- **Boot Command**: Historical QEMU command.

## Results
- **Boot Result**: FAIL.
- **Symptom**: Hangs at SeaBIOS/iPXE handoff.
- **Log**: See `logs/boot-recovery-20260909/boot_log.txt`.

## Conclusion
Switching to GZIP alone does not recover the boot. The issue is not simply the compression algorithm.
