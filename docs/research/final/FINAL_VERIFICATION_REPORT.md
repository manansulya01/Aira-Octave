# FINAL VERIFICATION REPORT — AiraOS-Octave 1.2.0

## What was tested (exact commands)

- `bash scripts/test-kernel.sh` — direct boot, markers + no panic/oops.
- `bash scripts/test-userspace.sh` — static layout + syntax.
- `bash scripts/test-services.sh` — guest autotest incl. 60+ IPC markers.
- `bash scripts/test-storage.sh` — two boots, marker persists.
- `bash scripts/test-network.sh` — `--net user` guest autotest.
- `bash scripts/test-gui.sh` — Xvfb desktop + apps + screenshot.
- `bash scripts/test-demo.sh` — demo tour markers.
- `bash scripts/test-iso.sh 1.2.0` — grub boot of shipped ISO.
- `bash scripts/test-release.sh 1.2.0` — build + `sha256sum -c` + ISO boot.
- Manual: 5×512M boots, 256M/1G/2G, SMP2 — all `userspace ready`.

## Results (final release)

All suites PASS on the 1.2.0 artifacts (see `logs/final-completion/` per-suite
`last.log` + timestamped logs). Flakiness found and fixed during the mission:

- IPC concurrent 3–4/5 under load → client timeout raised to 20s for the
  parallel probe (still requires 5/5; sequential bus documented).
- Harness 40s/150s timeouts too short for IPC-extended autotest → sized to
  220s (services/storage/network) and 280s (GUI). Assertions unchanged.
- GUI sysinfo content race (IPC slower than /proc under TCG) → synchronous
  `--once` probe + still launches the real popup window.
- Handler timeout only recognized GNU 124, but guest BusyBox returns 143 →
  now treats 124/143/137 as timeout (real bug, fixed + re-tested).
- `aira doctor` used `df /` (fails on initramfs root) → now `df` (fixed).

## Evidence locations

- `logs/final-completion/{baseline,userspace,services,storage,network,gui,
  demo,release,summary}/` — timestamped boots + `last.log` pointers.
- `docs/research/showcase/evidence/` — desktop screenshot (XWD).
- `release/aira-octave-1.2.0.sha256` — checksums of shipped files.
- In-guest markers: `GUEST AUTOTEST PASS`, `GUI TEST PASS`, `DOCTOR PASS`,
  60+ `GUEST-TEST OK: ipc ...`.

## Honesty statement

Nothing above is claimed without a passing probe. PARTIAL/UNTESTED/
UNSUPPORTED items are listed in FINAL_FEATURE_MATRIX + KNOWN_LIMITATIONS.
