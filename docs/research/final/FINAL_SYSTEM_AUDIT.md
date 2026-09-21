# FINAL SYSTEM AUDIT — AiraOS-Octave 1.2.0

Date: 2026-09-21. HEAD recorded at release time (see release notes + build logs).
Foundation: Linux 7.2.2 + BusyBox initramfs + aira CLI + airapkg + aira-init
services + Aira IPC bus + persistence + user-net + X11/JWM desktop + tests + ISO.

## Subsystem verdicts (evidence-backed)

- KERNEL/BOOT: VERIFIED — 5 consecutive 512M boots + 256M/1G/2G + SMP2, all
  `Linux version` + `Run /init` + `AiraOS userspace ready`, no panic/oops.
- INIT/SERVICES: VERIFIED — start/stop/restart/status/enable/disable, deps,
  USER=, oneshot/daemon, stale-PID→failed, shutdown ordering, crash→restart.
- IPC BUS: VERIFIED — daemon start/restart/kill-recovery, ping, list, all
  handlers, lifecycle via bus, emit/events, malformed/oversized/bad-version/
  bad-id/bad-names/unknown-service/unknown-method, handler timeout (10s),
  concurrent 5x, repeated 10x, priv-denied without token, priv-granted with
  token, token 600 + root-only, event cap 50. Integration: `aira status`,
  `aira doctor`, `aira demo`, System Information use the bus.
- SECURITY: VERIFIED (tested boundaries) — root+aira, /root 700, no setuid,
  home DAC, package traversal/symlink/hardlink rejection, IPC token gate.
  Honest gaps in KNOWN_LIMITATIONS (no login/firewall/encryption; root desktop).
- STORAGE: VERIFIED — /persist mount, write/readback, 2-boot marker round-trip.
- PACKAGES: VERIFIED — build/install/remove/verify/rollback/update-check,
  corrupt/invalid/traversal/symlink rejection, missing-dep warning, sample
  lifecycle (install → exact-output run → remove).
- NETWORKING: VERIFIED — lo up, loopback ping + TCP, eth0 via user-net where
  present, DHCP path exercised, GUI/CLI read the same interfaces/routes/DNS.
- GRAPHICS/DESKTOP/APPS: VERIFIED — Xvfb+Xorg fallback, JWM Aira menu/tray,
  9 apps launch + content checks + screenshot, desktop survives app exits.
- DEVELOPER: VERIFIED — sample C app builds, packages, installs, runs with
  exact output, removes (in-guest, with drive).
- OBSERVABILITY: VERIFIED — `aira diagnose` (now incl. IPC) + new
  `aira doctor` (per-area PASS/FAIL, exit code truthful).
- RECOVERY: VERIFIED — service kill→failed→restart, ipc kill→unreachable→
  restart→ping, shutdown stops all, syslog/klog recover.
- TESTING: VERIFIED — test-all 8 suites green on final release (see
  FINAL_VERIFICATION_REPORT); harness timeouts sized for IPC-extended autotest.
- RELEASE: VERIFIED — 1.2.0 dir + tarball + ISO + SHA256; checksums verify;
  exact ISO boots to userspace.

## Design decisions (why, not just what)

- Loopback TCP for IPC: sufficient for single-host OS v1; BusyBox nc `-ll -e`
  gives per-connection handlers with zero new dependencies. Hardened with
  protocol validation, timeouts, token auth, caps — not replaced for aesthetics.
- Sequential bus service: accepted and documented; concurrent test uses longer
  client timeout to match reality under TCG load.
- Software-rendered desktop fallback: correct when no GPU; virtio-GPU path
  detected honestly, not faked.
