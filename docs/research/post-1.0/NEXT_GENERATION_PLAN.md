# Next-Generation Plan (derived from post-1.0 audit evidence)

Principles: fix proven gaps before new scope; every item needs a guest test;
no remote trust without signatures; no HW claims without HW.

## 2.1 Packaging + test integrity (highest ROI, lowest risk)
- airapkg: reject `..`/absolute tar members; per-file sha256 manifest verified
  at install; stage-to-temp + rename for atomicity; persist DB under /persist
  when mounted (RAM fallback).
- test-all.sh: probe latest release ISO instead of pinned version; add
  truncated-tar + disk-exhaustion (small img) negative tests.
- Evidence gate: current rollback/corrupt tests keep passing.

## 2.2 Sessions + privilege separation
- Migrate X session to aira via USER= + Xauthority cookie; login via getty on
  serial+vty; keep root recovery console. Guest tests: cookie exists, session
  UID=aira, root console still works.
- Service hardening: drop syslog/net to least privilege where kernel allows;
  seccomp allowlist for airapkg extract path.

## 2.3 Graphics + input reality
- `--gpu virtio` boot variant asserting /dev/dri + Xorg (modesetting) start.
- evdev event injection test (keyboard) to replace XTEST-only evidence.
- Keep Xvfb as fallback; document both paths with logs.

## 2.4 Hardware honesty program
- -smp 2 boot assert; USB mass-storage passthrough test if host permits;
  publish results matrix regardless of outcome. No new drivers unless a
  concrete device target appears.

## 2.5 Developer SDK
- musl/static sample variant (no guest-glibc coupling); SDK sysroot .apkg;
  guest git/busybox-vi workflow doc; app icon XPM spec + 2 sample icons.

## Explicit non-goals (from audit)
Custom kernel subsystems, TCP/IP reimplementation, remote repos before trust
model, benchmark optimization without measurements, physical-HW claims.
