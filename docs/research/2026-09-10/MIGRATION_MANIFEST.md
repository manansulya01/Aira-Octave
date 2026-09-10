# AiraOS-Octave — Migration State

Date: 2026-09-10

## Repository

- Repository: `manansulya01/Aira-Octave`
- Branch: `main`
- Migration source: WSL development environment
- Migration target: macOS/iMac development environment

## Preserved

- Linux 7.2.2 source tree
- AiraOS-Octave configurations
- current local kernel configuration
- initramfs source and BusyBox userspace
- reproducible QEMU boot scripts
- kernel/userspace reports
- configuration comparison evidence
- historical successful boot evidence
- boot recovery investigation
- K3/K4 forensic investigation
- kernel completion investigation
- architecture/configuration audit

## Excluded

Generated or redundant artifacts:

- Linux source archive
- generated kernel binaries
- generated vmlinux
- generated initramfs archive
- generated ISO images
- generated QEMU test directories
- giant raw Git commit dumps
- disposable build output

## Current state

AiraOS-Octave currently uses upstream Linux 7.2.2 as its kernel
foundation, with AiraOS-Octave configuration and custom initramfs/userspace.

Historical K3 artifacts successfully reached AiraOS userspace.

The current investigation is focused on reproducing and explaining the
later boot failure before broader platform development continues.

## Migration principle

GitHub stores reproducible source, configuration, scripts, reports, and
important research evidence. Machine-specific build products remain
regenerable on the target machine.
