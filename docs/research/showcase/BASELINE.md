# Showcase Baseline — AiraOS-Octave 1.1.0 (2026-09-19)

## Checkpoint
- Safety branch: `checkpoint/showcase-start-20260919` (HEAD at start of work).
- Working-tree patch preserved: `/tmp/opencode/checkpoint-showcase-start/working.diff`.
- Classification of pre-existing working-tree changes:
  - A) intended dev (PRESERVED): `gui/aira-jwmrc` (tray indicators, menu categories),
    `gui/aira-session` (helper symlinks), `initramfs/init` (aira_gui auto-desktop),
    `scripts/build-gui.sh` (indicator staging), new `gui/aira-net-indicator`,
    `gui/aira-storage-indicator`.
  - B) generated artifact (rebuilt, not hand-edited): `initramfs.cpio`.
  - C/D/E) NOT committed: `logs/`, `release/`, `docs/research/2026-09-1*/`,
    `.config`, `config_diff_*.txt` (logs/evidence/temp/release artifacts).

## Baseline run (before source changes)
- `bash scripts/test-all.sh` → TEST-ALL PASS (8/8: kernel, userspace-static,
  services, storage, network, gui, demo, iso) on the frozen tree.
- `initramfs.cpio` was IN-SYNC with `initramfs/init` (verified via cpio extract + diff).
- Kernel: Linux 7.2.2 x86_64, bzImage `e198875c` (15M). QEMU 10.2.1, gcc 15.2.0.
- Known 1.0.0 limitations carried in: airapkg unsandboxed paths / non-atomic /
  blind +x (all FIXED in 1.1.0, see SECURITY_REPORT).

## Baseline version / artifacts (1.1.0 after bump)
- Version 1.1.0 (`initramfs/etc/os-release`, `motd`, `aira VER`).
- bzImage `e198875c`, initramfs `82a9588b`, rootfs `5569686e`, ISO `7e9c0821`,
  tar `e7f195e1` (see `release/aira-octave-1.1.0.sha256`; working files match
  release files byte-for-byte).
