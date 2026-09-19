# Showcase Baseline (1.0.0 @ d3854000a, verified 2026-09-18)

## WHAT WAS TESTED
Full existing suite on the frozen tree (no source changes):
test-all.sh → kernel, userspace-static, services, storage, network, gui,
demo, iso.

## RESULT
TEST-ALL PASS (8/8). Each suite PASS with serial-log evidence under
logs/final-completion/ (2026-09-18 12:08–12:10 runs).

## KNOWN FAILURES
None reproducible at baseline: all suites pass. Two observations carried
forward for investigation (mission §2 K/L): the `/proc/sys/kernel/hotplug`
message and a prior inconsistent-service-state boot. Neither reproduced yet.

## KNOWN LIMITATIONS (from 1.0.0 audit, still standing)
- airapkg: no tar path sandboxing; non-atomic install; RAM-only DB.
- test-all.sh pins stale 0.2.0 ISO.
- Desktop/services run as root; file-mgr/settings click-through manual;
  virtio-GPU/DRI path untested; physical HW untested; user-net only;
  local package repo only.

## CURRENT VERSION / COMMIT / ARTIFACTS
- Version: 1.0.0 (os-release + aira VER). HEAD: d3854000a (docs only over ddce83dfd).
- bzImage e198875c (15M), initramfs c7f1fd49 (2.2M), config 80a13a5f.
- Release 1.0.0 tarball+ISO+sha256 present (boot-tested at release time).
- Toolchain: gcc 15.2.0, ld 2.46, QEMU 10.2.1, x86_64.
