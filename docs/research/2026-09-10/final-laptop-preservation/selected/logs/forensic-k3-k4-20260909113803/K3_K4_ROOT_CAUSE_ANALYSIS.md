# K3 vs K4 Boot Regression Forensic Analysis

## Findings

### PROVEN
- K3 bzImage size: ~15 MB.
- K4 bzImage size: ~2.4 MB.
- K3 compression: GZIP (from historical `file` output).
- K4 compression: XZ (from current `.config`).
- K3 metadata: syssize 0xe5640, init_size 0x2aec000.
- K4 metadata: syssize 0x25140, init_size 0xde9000.
- K3 reached "AiraOS userspace ready".
- K4 hangs at SeaBIOS handoff.
- K3 `CONFIG_INITRAMFS_SOURCE` was empty (initramfs provided externally).

### INFERRED
- There is a divergence in the build configuration or environment used for K3 versus K4.

### UNKNOWN
- The exact `.config` used for K3.
- The causal relationship between the binary size/compression and the boot failure.
- Whether `CONFIG_DEBUG_INFO` was enabled for K3.
- The specific meaning of the `syssize` difference in this context.

## Conclusion
A build divergence exists between the successful K3 and failing K4 kernels, characterized by different compression methods and binary sizes. The exact configuration that led to the successful boot of K3 has not been recovered.

K3_COMPRESSION=GZIP
K4_COMPRESSION=XZ
K3_BZIMAGE_SIZE=15 MB
K4_BZIMAGE_SIZE=2.4 MB
K3_CONFIG_RECOVERED=NO
K3_DEBUG_INFO_PROVEN=NO
K3_GZIP_PROVEN=YES
CONFIG_DIFF_CONFIRMED=NO
ROOT_CAUSE_CONFIDENCE=LOW
SAFE_NEXT_EXPERIMENT=Recover the exact K3 build configuration/evidence before changing anything
