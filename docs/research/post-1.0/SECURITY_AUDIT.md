# Post-1.0 Security Audit (1.0.0 @ ddce83dfd; guest-executed unless noted)

Evidence: logs/final-completion/services/services-20260918-112800.log
(security section), static staging inspection 2026-09-18. No destructive tests.

## VERIFIED controls
- DAC boundary: aira denied /root, allowed own home (guest-executed).
- /root 700 enforced by /init (guest-asserted). /home/aira 1000:1000.
- No setuid/setgid in /bin /sbin /usr/bin (guest-scanned each boot).
- Service defs 644 root-owned; /etc root-owned → aira cannot alter services
  (by ownership+DAC; mechanism guest-proven, specific write-attempt untested).
- Services support USER= with ownership-proven non-root execution.
- No TCP listeners by default (guest-scanned).
- Package install rejects missing files + corrupt tars (guest-tested).
- Shutdown/reboot require --force (guest-tested guards).
- No eval/unquoted expansions on user input in aira/airapkg/settings paths
  (reviewed: hostname/cp/grep/udhcpc args quoted; su uses fixed -s).

## Findings

### HIGH — airapkg has no path sandboxing (code-inspected, not exploited)
- `install` builds destinations as `/$rel` from tar member names
  (initramfs/usr/bin/airapkg, install branch) and `tar -xzf` runs without
  validation. A hand-crafted .apkg (bypassing `airapkg build`) with `../`
  members could write outside intended paths.
- Concrete condition: attacker must already convince root to
  `airapkg install evil.apkg` from the LOCAL repo (no remote fetch exists,
  no signatures exist). Impact capped by operator trust + local-only design.
- Evidence: source lines (install loop, tar extract). NOT executed (would need
  guest code changes; audit-only per mission).
- NEXT: canonicalize members, reject absolute/`..` paths, add sha256 manifest.

### MEDIUM — package trust = none
- No signatures, no hashes; DB in RAM (rollback state lost on reboot).
- Consistent with local-only design; BLOCKS any future remote repo until fixed.

### MEDIUM — desktop/X run as root in tests
- Xvfb/JWM/apps root; X socket dir 1777, no -auth cookie. Contained by
  QEMU isolation + no network listeners. USER= mechanism exists but session
  not yet migrated.

### LOW — serial console is root without login
- By design (recovery requirement). Becomes HIGH if images ever boot on
  shared/physical hardware with untrusted console access.

### INFORMATIONAL
- /tmp,/run,/dev/shm rely on tmpfs default 1777 (not explicit chmod).
- SELinux compiled but unenforced; seccomp unused by Aira code; both are
  available hardening levers, not gaps in the stated model.
- Service logs world-readable (fine for single-user demo scope).
