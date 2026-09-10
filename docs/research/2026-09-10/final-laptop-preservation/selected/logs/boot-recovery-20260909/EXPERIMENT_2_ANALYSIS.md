# Experiment 2 Analysis: Structural Comparison of K3 and Current GZIP Kernel

## PROVEN
- **Current GZIP Binary Size**: 3.0 MB.
- **Historical K3 Binary Size**: ~15 MB.
- **Current GZIP Protocol**: 2.15.
- **Current GZIP Metadata**:
    - `syssize`: 0x2f440 ($\approx 193$ KB)
    - `init_size`: 0xde9000 ($\approx 14$ MB)
- **Historical K3 Metadata**:
    - `syssize`: 0xe5640 ($\approx 925$ KB)
    - `init_size`: 0x2aec000 ($\approx 44$ MB)
- **Compression**: Both use GZIP.
- **Initramfs**: Both use external initramfs (`CONFIG_INITRAMFS_SOURCE=""`).
- **Boot Result**: Both current GZIP and original XZ kernels hang at the SeaBIOS/iPXE handoff.

## INFERRED
- **Memory Requirement Divergence**: K3 requires 3x more linear memory during initialization (`init_size`). This is a massive difference and suggests the kernel payload in K3 is significantly larger.
- **Setup Code Divergence**: The `syssize` difference ($\approx 732$ KB) indicates a different amount of real-mode setup code or different options enabled in the boot-up sequence.

## UNKNOWN
- **The Causal Variable**: It is unknown whether the boot failure is due to the *lack* of specific data (which would increase size) or a *wrong* value in the setup header that causes the bootloader to fail the handoff.
- **Causal Relationship with DEBUG_INFO**: While `DEBUG_INFO` increases size, it is not yet proven that its *absence* causes the boot failure.

## STRUCTURAL DIFFERENCES

| Feature | Current GZIP Kernel | Historical K3 | Difference |
| :--- | :--- | :--- | :--- |
| **bzImage Size** | 3.0 MB | ~15 MB | +12 MB (K3) |
| **syssize** | 0x2f440 | 0xe5640 | +0xb6200 (K3) |
| **init_size** | 0xde9000 | 0x2aec000 | +0x2313000 (K3) |
| **Compression** | GZIP | GZIP | None |

## MOST LIKELY NEXT VARIABLE
**Boot Protocol/Setup Header values.**

## WHY THAT VARIABLE
The kernel hangs at "Booting from ROM.." or "Press Ctrl-B...". This is the exact moment the bootloader (SeaBIOS/iPXE) hands off execution to the kernel's real-mode setup code. If the bootloader finds the setup header invalid, or if the `syssize`/`init_size` values are incompatible with the environment's memory map, it will hang or crash before the first line of Linux kernel code (the Linux banner) is even executed.

## EXPERIMENT_3 (Revised)
Since `DEBUG_INFO` did not fix the boot (it just increased size), the next step is to identify a configuration that changes the **setup header** or **real-mode behavior**. 

We will investigate `CONFIG_RELOCATABLE` and EFI-related options, as these fundamentally change how the `bzImage` is laid out and how it is handed off by the bootloader.

K3_SIZE=15 MB
CURRENT_GZIP_SIZE=3.0 MB
K3_SETUP_SIZE=0xe5640
CURRENT_SETUP_SIZE=0x2f440
K3_SYSSIZE=0xe5640
CURRENT_SYSSIZE=0x2f440
K3_INIT_SIZE=0x2aec000
CURRENT_INIT_SIZE=0xde9000
K3_CONFIG_KNOWN=NO
COMPRESSION_CAUSALITY=DISPROVEN
SOURCE_DIFFERENCE_PROVEN=NO
NEXT_VARIABLE=Setup Header / Boot Protocol
EXPERIMENT_3=Analyze and test CONFIG_RELOCATABLE and EFI_STUB combinations.
