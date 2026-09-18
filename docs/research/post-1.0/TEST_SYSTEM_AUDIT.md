# Post-1.0 Test-System Audit (audit the tests themselves)

## What test-all.sh proves (8 suites, 2026-09-18 run: 8/8 PASS)
Kernel markers+no-panic; static syntax+layout; service lifecycle incl.
crash/recovery/shutdown; 2-boot persistence; lo+virtio-net+TCP; X startup,
≥5 mapped windows, app content, screenshot, desktop survival; demo tour;
ISO boot. Each asserts machine-checkable markers with exit codes. Genuine.

## Confirmed weakness: stale ISO under test
- test-all.sh line 28 hardcodes `test-iso.sh 0.2.0` while the release is 1.0.0.
  The suite therefore validates a STALE artifact. Found during this audit.
- Impact: release-pipeline coverage actually comes from test-release.sh
  (builds+boots current), which is separate. Fix recommended (probe latest
  release ISO); recorded as debt, fixed post-audit only if sanctioned.

## Timing dependence (acknowledged, mitigated)
- GUI poll up to 60s + count-based window matching: robust across observed
  TCG variance (9s vs 40s mapping), but still wall-clock dependent. Titles
  asserted INFO-only for this reason. Nondeterminism accepted openly.
- QEMU_EXIT=124 (timeout kill) treated as PASS for shell-hang boots: correct
  by design (guest idles at shell), but a boot that hangs EARLY would also
  yield 124 — mitigated by requiring markers first. Sound.

## False-positive risks (reviewed, controlled)
- `grep -q root` style weak asserts were removed during 0.2/1.0 hardening
  (terminal-window, syslog-running, content asserts). Remaining INFO-level
  checks cannot pass the suite alone.
- userspace-static MISS on initramfs/var/log/airaos is tolerated (runtime dir).
  Documented; suite still passes. Minor debt: make the check create-or-skip.

## Coverage gaps (no test)
- Multi-vCPU boot, OOM, disk-full, truncated-valid-tar install, JWM restart
  in-session, DRI/GPU path, physical input events, upgrade 0.x→1.0 in place.
- Negative tests present for: unknown service, invalid/corrupt package,
  shutdown guards, DAC deny. Missing for: malformed JWMRC, bad fstab entry,
  full /persist, killer OOM during X.

## Verdict
Suite is honest and load-bearing (it caught real bugs: nohup, su order,
xkbcomp, fonts, PATH lookup). Keep; fix ISO staleness; add the listed
negative tests before any 2.x claims.
