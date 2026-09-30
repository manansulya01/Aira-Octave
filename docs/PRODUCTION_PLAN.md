# AiraOS-Octave Production Plan (post-1.5.0)

Baseline: `v1.5.0` tag = `ec73ef1` (AiraOS-Octave 1.5.0, Linux 7.2.2, x86_64).
Rule: never modify the tag; work forward in small commits; no push without request.

This document is the required pre-work: dependency map of the existing
architecture, then the phased implementation plan. It is updated as phases land.

## 1. Dependency Map (verified by inspection, 2026-09-30)

```
linux-7.2.2/  (94855 tracked files: full kernel source + .config)
  │  configs/airaos-octave-x86_64.config  (tracked build config)
  ▼
bzImage  (IGNORED build product, scripts/build-kernel.sh)
  │
  │   initramfs/  (158 tracked files: THE root filesystem source)
  │     init (PID 1, busybox sh)
  │       ├─ mounts /dev /proc /sys /tmp /run /dev/shm /dev/pts
  │       ├─ mdev -s device population
  │       ├─ mounts /persist from /dev/vda (best-effort ext4)
  │       ├─ /sbin/aira-init boot (service supervisor)
  │       │    ├─ syslog, klog (logging; enabled by default)
  │       │    ├─ persist (dirs; enabled), net (dhcp; enabled), ipc (bus; enabled)
  │       │    └─ device, hardening, recovery, user-session (defined, NOT enabled)
  │       ├─ GUI autostart: /persist/usr/bin/aira-session (preferred) or
  │       │   /usr/bin/aira-session, when aira_gui=1
  │       └─ test modes: aira_autotest / aira_guidemo / aira_guivisible /
  │           aira_inputtest / aira_fileops / aira_demo
  │     /sbin: aira-init, aira-ipcd, aira-ipc-handle, aira-install,
  │            aira-update, aira-recovery, aira-hardening, aira-getty,
  │            guest-*.sh (in-guest test harnesses)
  │     /usr/bin: aira (frontend), airapkg, aira-ipc, aira-user, aira-power,
  │            aira-audio, aira-sdk, aira-log, aira-info, aira-demo,
  │            aira-device-setup, aira-net-setup
  │     /etc/aira: services/*.conf, enabled/* (symlink set), ipc/handlers/*
  │     /etc: passwd/shadow/group, os-release (1.5.0), hostname, motd
  │     /var/lib/airapkg: installed/ + repo/ (package DB)
  │  build: scripts/build-initramfs.sh ──► initramfs.cpio (IGNORED product;
  │     note: one stale copy is historically tracked, do NOT rely on it)
  ▼
kernel + initramfs.cpio  →  QEMU direct boot (scripts/boot-qemu.sh)

gui/  (22 tracked files: desktop source of truth)
  │  aira-session (Xvfb/Xorg backend select + jwm launcher)
  │  aira-jwmrc (single bottom tray; taskbar+pager+tray+clock)
  │  apps: terminal, file-manager(mc), textedit(vi), settings, sysmon,
  │        sysinfo, netman, pkgcenter, about, welcome, help, notify/notifyd,
  │        session-mgr, dm, clock, net/storage indicators, gui-test
  │  build: scripts/build-gui.sh (unpacks Ubuntu debs into rootfs/ + copies gui/*)
  ▼
rootfs/  (IGNORED staging) ──► scripts/build-rootfs.sh ──► aira-rootfs.img
  (IGNORED 512M ext4; mounted at /persist by /init; PROVIDES the desktop:
   NO -drive image ⇒ NO graphical session — text shell only)

release: scripts/build-release.sh ──► release/aira-octave-$VER/
  (boot/bzImage, boot/initramfs.cpio, aira-rootfs.img, grub ISO, sha256)
  release/ outputs are IGNORED/untracked products; reproducible via scripts.

tests: scripts/test-{all,kernel,userspace,services,storage,network,gui,demo,
  features,full,input,iso,release}.sh  +  initramfs/sbin/guest-*.sh (in-guest)
```

### Load-bearing dependencies (do not break)

1. `/init` contract: mounts → mdev → /persist → `aira-init boot` → shell.
   Every phase must keep text boot green (`scripts/boot-qemu.sh --timeout 30`).
2. Desktop ONLY exists via /persist (`-drive aira-rootfs.img`). gui/ changes
   require `build-gui.sh` + `build-rootfs.sh` re-stage to take effect in QEMU.
3. `aira-session` backend selection (Xorg-when-GPU else Xvfb) is the tested
   matrix (`--auto/--xorg/--xvfb/--headless`). Keep all four working.
4. IPC bus (`aira-ipcd`, 127.0.0.1:41234, AIRA1) is the API surface new apps
   must use — no duplicate system logic (per mission Phase 2 rule).
5. `airapkg`: atomic staged install + rollback is the update/recovery
   foundation (Phases 5/13 build on it, not around it).

## 2. Implementation Order (dependency-driven, not mission-numeric)

The mission lists 16 phases; build order follows dependencies:

- WAVE A (foundation, no user-visible risk): observability hooks (14-lite:
  extend `aira doctor/diagnose`, never remove), developer/CI test harness
  (16: `test-shell.sh` + QEMU regression), theme/wallpaper config plumbing.
- WAVE B (shell, Phase 1): top panel + dock + launcher + search + quick
  settings + notifications + workspaces — all as JWM-native config + POSIX
  sh tools (no new compiled deps; X11/JWM stack unchanged).
- WAVE C (apps, Phases 2-4): graduate wrappers → IPC-backed tools, one app
  per commit (Files tabs/trash, Settings write-path per panel, Terminal,
  Monitor, Software, Welcome/About).
- WAVE D (platform, Phases 5-10): remote repo + signatures (5), users/sessions
  with non-root desktop (6 — needs getty/dm/session rework, HIGH RISK, needs
  QEMU login test), security enforcement matrix (7 — claim only what tests
  prove), network/audio/hardware GUIs wired to existing handlers (8-10).
- WAVE E (system lifecycle, Phases 11-13): accessibility settings (11),
  graphical installer (12 — extends aira-install, needs ISO test), atomic
  update/rollback verification + recovery shell tests (13).
- WAVE F (hardening for DONE, Phase 16 continuous): failure-injection tests
  (disk-full, corrupt pkg, killed service, low-mem) for every feature merged.

Ubuntu 26.04 docs are REQUIREMENTS INPUT only: behaviour parity (installer
steps, settings panels, update flows, accessibility options) with original
Aira mechanisms. No Ubuntu code/assets/branding.

## 3. Rules of Engagement

- Small logical commits; `git status/diff/log` reviewed before each commit.
- Never `reset --hard`, never delete working features without evidence.
- Every commit: WHAT FOUND / WHAT CHANGED / WHY / TEST COMMAND / RESULT /
  EVIDENCE / REMAINING LIMITATION (in commit message + turn report).
- No "complete" claim from code existence alone — QEMU/static evidence required.
- JWM validity: `xmllint --noout` on every jwmrc change (jwm binary absent
  on build host); full behaviour check in QEMU GUI test.
- POSIX sh only for shell tools (`sh -n` + busybox-sh compatible, no bashisms
  in initramfs-reachable code; gui tools may use bash ONLY if already staged
  with bash present — they run on rootfs Ubuntu userspace, so `#!/bin/sh`
  dash-compatible is still preferred).

## 4. Landing Log

- 2026-09-30 — Baseline preserved: tag `v1.5.0` created on `ec73ef1`
  (no such tag existed; creation is preservation, not modification).
- 2026-09-30 — WAVE B increment 1 (planned): Aira top panel + dock +
  launcher + quick settings + theme engine + wallpaper (JWM-native,
  additive, old single-tray layout kept as `aira-jwmrc.classic` fallback).
