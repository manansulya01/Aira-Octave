# AiraOS-Octave Master Production Architecture

Baseline: `v1.5.0 = ec73ef1ca` (permanent historical tag, do not rewrite).
Head audited: `5d3f81430 fix(b2): correct JWM numeric workspace shortcuts`
(B-2 complete: JWM XML, shell 107/107, features 52/52, userspace static,
GUI QEMU, launcher, quick-settings, themes, wallpapers, notifications,
workspaces, shortcuts, session integration).
Date: 2026-10-03. DO NOT PUSH.

This document maps **every** requirement in the Master Mission (§33–§43 plus
Waves C–O) to: existing implementation, missing implementation, dependency,
test, evidence source, risk, expected milestone. Status words used:
VERIFIED / SUPPORTED / PARTIALLY VERIFIED / HARDWARE DEPENDENT /
NOT YET VERIFIED / KNOWN LIMITATION.

Companion: `docs/architecture/WAVE-C-ARCHITECTURE.md` (§1–§13, incl. C0 audit).

## 0. Current architecture (verified by reading source)

- Kernel 7.2.2 (`configs/airaos-octave-x86_64.config`), `/init` PID 1
  (mounts → mdev → `/persist` on `/dev/vda` → `aira-init boot` → shell).
- `aira-init`: pidfile supervision, daemon/oneshot, deps, respawn limits.
- AIRA1 IPC v1 on 127.0.0.1:41234 (`aira-ipcd` via `nc -ll -p -e
  aira-ipc-handle`; 7 handlers: bus/device/network/services/storage/system/user;
  root-token DAC auth; 8 KiB line cap; 10 s handler timeout).
- CLI: `aira-ipc`, `aira`, `aira-info`, `aira-log`, `aira-net-setup`,
  `aira-device-setup`, `aira-power`, `aira-audio`, `aira-user`, `airapkg`
  (atomic staged install + rollback, traversal/symlink rejection, no sourcing
  of PKGINFO).
- C0 lib (this milestone): `usr/lib/aira-ipc.sh` canonical;
  `initramfs/usr/lib/aira-ipc.sh` tracked guest copy;
  `rootfs/usr/lib/aira-ipc.sh` staged by `build-gui.sh`;
  consumers `gui/aira-settings`, `gui/aira-sysinfo` use it with
  missing-lib/bus fallbacks.
- Desktop: JWM (`gui/aira-jwmrc` only WM input; classic pinned to v1.5.0 SHA),
  Xorg-or-Xvfb via `aira-session`, top panel + dock + launcher + quick
  settings + theme engine (6 themes) + 6 wallpapers + notifyd FIFO.
- Apps today are wrappers over real CLIs (`mc`, `vi`, `xterm`, `airapkg`,
  `ip`, `df`…); direct IPC use is new (C0) and partial.
- Tests: `test-shell.sh` (107 host), `test-features.sh` (52),
  `test-userspace.sh`, `test-gui.sh`, `test-storage/network/services/input/iso/
  release/full/kernel.sh`; guest harnesses `guest-autotest/demo/fileops/
  guidemo/guivisible/inputtest.sh`. QEMU is primary automated env.

## 1. Wave C — Application architecture (START HERE)

| ID | Requirement | Existing | Missing | Dependency | Test | Evidence | Risk | Milestone |
|----|-------------|----------|---------|------------|------|----------|------|-----------|
| C0 | shared IPC client: framing, auth, timeouts, errors, capability discovery, status codes, safe args; small, no giant framework | `aira-ipc` CLI + `usr/lib/aira-ipc.sh` (call/emit/list/ping/available/has_service/print; validation; `set -u` safe) | per-method help verb; async subscribe; unix-socket transport | `aira-ipcd`, `nc`, `timeout` | `sh -n`; `test-shell.sh`; guest autotest | shell 107/107; guest AUTOTEST PASS 128 OK/0 FAIL (c0-autotest.log 2026-10-04) | VERIFIED guest | C0 DONE + VERIFIED |
| C1 | Files: browse, create/rename/copy/move/delete, trash, perms/owner/times/size, free space, mounts, hidden, errors, safe paths, traversal guard, cancel | `files` IPC service (caps/list/stat open; mkdir/rename/copy/move/delete root-token) + `aira-files` CLI (bus-first, local fallback) + manager `--once`/`--text`; `mc` graphical backend retained | trash spec; recursive/tree ops; progress-cancel streaming; non-root writer roles (needs D3) | `stat/readlink/cp/mv/mkdir/rm` fixed-argv only | `test-files.sh` 56/56 host + guest FILEOPS PASS w/ drive (c1-fileops-drive.log) | VERIFIED (host+guest, bus+local, attacks rejected) | shell-injection forbidden (no eval, `|`-split args) | C1 DONE 2026-10-04 |
| C2 | Settings: 11 categories, every control → real state, UNAVAILABLE/UNSUPPORTED, persist | central store (schema v1, 12 keys) + `settings` IPC (get/list/caps open; set/reset root-token) + `aira-cfg` CLI + managed UI section; validate→cap-gate→apply→atomic store | per-key events; double-boot proof; non-root writers (D3) | schema + `stat/flock/hostname/amixer/iw/sysfs` | `test-settings.sh` 55/55 host + guest SETTINGS PASS 23/23 (c2-settings.log) | VERIFIED (host+guest, bus+local, corruption+concurrency+priv) | fake controls forbidden (UNAVAILABLE enforced in backend) | C2 DONE 2026-10-04 |
| C3 | Terminal: PTY, lifecycle, resize, env, cwd, keyboard/signals, exit, theme, multi-session, no recovery-console interference | `aira-terminal` = themed xterm wrapper (copy/paste, geometry) | real PTY manager (only xterm today) | `xterm`, `posix_openpt` path for future native term | gui + input tests | PARTIALLY VERIFIED (wrapper, not PTY owner) | interfering with serial recovery shell | C3 |
| C4 | Monitor: cpu/mem/load/uptime/procs/storage/net/svc/temp/battery, no fabrications, no poll-storm | `aira-sysmon --once` (cpu % via /proc/stat delta, mem, load, ps, df, ip) + xterm live loop | IPC enhancements (cpu%, mem%, per-proc, temp, battery verbs) or justified direct reads | `/proc`, `/sys/class/power_supply`, `/sys/class/thermal` | host + guest monitor smoke | PARTIALLY VERIFIED | 1 s poll × many clients | C4 |
| C5 | NetMan: ifaces, link, v4/v6, routes, DNS, DHCP, CONNECTED/CONNECTING/DISCONNECTED/FAILED/UNAVAILABLE/UNSUPPORTED, diag | `aira-netman --once/--menu` (ip/ifconfig, routes, resolv.conf, udhcpc renew, ping) + `network` IPC read-only | privileged config verbs (up/down, addr, routes, DNS) with root-token gate | `ip`, `udhcpc`, `network` handler | `test-network.sh` + guest | PARTIALLY VERIFIED (read + DHCP renew real) | privileged net config without authZ | C5 |
| C6 | Software Center: use airapkg, no 2nd PM; list/search/info/install/remove/update/tx-status/rollback/repo; signed metadata path | `aira-pkgcenter --text` over real `airapkg`; `airapkg` atomic + rollback + verify | repo signing/verification enforced; structured IPC or stable parse contract | `airapkg` DB `/var/lib/airapkg` | `test-iso/release.sh`, pkg tests | PARTIALLY VERIFIED (local repo only) | remote repo + sig bypass | C6 |
| C7 | Diagnostics: kernel/version/boot/svc/IPC/storage/net/devices/pkgs/security/logs/recovery/caps; reuse tools | `aira diagnose/doctor/info/status`, `aira-sysinfo --once`, `guest-autotest.sh` | unified diagnostics app aggregating all (today scattered) | all handlers + logs | full suite | PARTIALLY VERIFIED | duplicating log sources | C7 |
| C8 | Help: About/Welcome/Help + docs + diagnostics + recovery guidance, no doc duplication | `aira-about/welcome/help`, SHOWCASE docs | first-boot detection; help→doc linking (`/usr/share/doc/aira-octave`) | docs tree | gui tests | PARTIALLY VERIFIED | stale duplicated docs | C8 |

## 2. Wave D — Platform maturity

| ID | Requirement | Existing | Missing | Test | Risk | Milestone |
|----|-------------|----------|---------|------|------|-----------|
| D1 Users | multi-user, creation, passwords, groups, homes, ownership | `/etc/passwd/shadow`, `aira-user`, `user` IPC (list/current/info/groups) | real multi-user desktop ownership (desktop still effectively single-user) | `test-userspace.sh` | desktop permanently root-owned | D |
| D2 Sessions | login/logout/lock, isolation | `aira-session`, `aira-dm`, `aira-session-mgr` (kill-jwm / shutdown) | session ownership + lock + isolation | gui session tests | session confusion | D |
| D3 Privsep | least privilege, no permanent root desktop | `su -c` for unprivileged services; `PRIV_METHODS` gate | move desktop/apps off root; backend-enforced perms (not GUI-only) | failure-injection: unauthorized IPC | GUI-only checks | D/E |
| D4 Proc lifecycle | spawn/reap/supervise, cleanup | `aira-init` supervision + respawn limits | cgroup-scoped lifecycle, exit-code accounting | services tests | zombies/leaks | D |
| D5 Supervision | deps, health, restart policy | deps + `status/logs/diag` | parallel start, health checks, quotas | `test-services.sh` | boot latency vs parallelism | D |
| D6 Devices | discovery + permissions + hotplug | `device` IPC (pci/usb/input/virtio/block/net) + `aira-device-setup` | hotplug/autoconfig policy, ACLs | guest device tests | missing-device crash | D/H |
| D7 Storage | mgmt: mounts, quota, fsck path | `storage` IPC (usage/mounts/persist) + `persist.conf` | quota, fsck hooks, atomic-state pattern everywhere | `test-storage.sh` | silent corruption | D/§33.4 |
| D8 Networking | managed lifecycle, not one-shot DHCP | `net.conf`, `aira-net-setup`, udhcpc script | connection state machine, reconnect/backoff | `test-network.sh` | flapping | D |
| D9 Audio | smallest viable stack, vol/mute/device/mic/notify streams | `aira-audio` CLI (honest unavailable on QEMU) | device-select + stream policy; no heavy PA unless justified | honest-unavailable tests | heavyweight stack | D/I |
| D10 Power | suspend/battery/backlight policy | `aira-power` + indicators (honest unavailable) | suspend/hibernate, lid/AC policy | unavailable-path tests | unsafe suspend | D |
| D11 HW discovery | cpu/ram/pci/usb/storage/net/gpu/input/audio/battery/thermal | `device` IPC + sysfs reads in apps | coherent HAL abstraction over kernel interfaces | hardware matrix | driver invention (forbidden — use Linux) | D/H |
| D12 Graphics/input | Xorg/Xvfb select, kbd/mouse | `aira-session --auto`, xrandr/xsetroot/xmessage path | multi-monitor, hotplug, input latency budget | `test-gui/input.sh` | compositor bloat | D/§34 |

## 3. Wave E — Security (first-class; every control needs an enforcement test)

Loopback-only bus; root-token DAC; `PRIV_METHODS` gate; input/length validation;
airapkg traversal/symlink/PKGINFO guards; `hardening.conf` sysctls; cgroups v2;
shadow passwords. MISSING: capabilities/namespaces/seccomp/AppArmor audit with
CONFIGURED/VERIFIED matrix; side-channel mitigation table (Spectre/Meltdown:
PRESENT/CONFIGURED/VERIFIED/N-A/NOT-VERIFIED); sandboxing; audit logging; signed
pkg/update verification; firewall/netfilter; secure boot/TPM; encrypted storage.
Rule: do not merely compile features — prove what each prevents (unauthorized
IPC, priv-esc, pkg tamper). Milestone E with failure-injection (§38).

## 4. Wave F — Installation

`aira-install` exists (initramfs) but no verified matrix for: boot media, HW/disk
detect, partitioning, fs select, user/hostname/timezone/net, encryption,
bootloader, verification, logs, safe-failure (never leave half-configured system
unreported). Status: NOT YET VERIFIED. Milestone F.

## 5. Wave G — Update + recovery

`aira-update` + `aira-recovery` (check/fix services/storage/net/IPC/pkgs/graphics)
exist; `airapkg rollback` per-package. MISSING verified pipeline:
CHECK→DOWNLOAD→VERIFY→STAGE→VALIDATE→SWITCH→VERIFY-BOOT→MARK-SUCCESS with
atomic versioned state + deliberately-failed-update rollback test + recovery env
+ fsck + diag-boot. Never claim rollback without the failed-update test. Milestone G.

## 6. Wave H — Hardware (§33.3, §39)

Linux is the driver foundation; Aira = abstraction + failure handling.
Discovery: see D11. Required evidence per path: discovery + absent-device +
timeout + reset + interrupt stress + DMA path + recovery. Buggy-hw, async-IRQ
(storms/spurious/affinity), DMA (map/unmap, ownership, IOMMU, reset) are
NOT YET VERIFIED at Aira layer (kernel provides mechanisms; Aira policy
untested). Compatibility matrix must separate QEMU-VERIFIED / PHYSICAL-VERIFIED /
LINUX-GENERIC / HARDWARE-DEPENDENT / NOT-YET-VERIFIED. No bare-metal claims
without evidence.

## 7. Wave I — Audio (§34-era)

See D9. Decide smallest stack (ALSA direct vs minimal daemon); expose
playback/volume/mute/device/mic/notify streams; honest UNSUPPORTED where
absent. NOT YET VERIFIED beyond `aira-audio` status.

## 8. Wave J — Accessibility (§34.4)

Keyboard nav exists (JWM keys, launcher `--text`); visible focus, high-contrast
themes, font scaling, reduced-motion, color-independent status, a11y shortcuts,
screen-reader API/tree are NOT YET VERIFIED. Never claim SR support without a
real accessibility tree. Milestone J with GUI (§34).

## 9. Wave K — Developer platform

`aira-sdk`, `samples/hello-aira` (Makefile + PKGINFO), IPC example doc, `aira
diagnose/log`. MISSING: SDK headers, pkg/svc templates, IPC API docs site,
debugging/profiling/crash-reporting story; dev tools installable (not base).
PARTIALLY VERIFIED.

## 10. Wave L — Observability

`aira log/doctor/info/status/diagnose`, service logs, `ipc.log`,
`notifications.log`, boot/dmesg logs. MISSING: structured logs, levels,
rotation, persistent crash/app-failure bundles, health checks, "what went
wrong?" without grepping random kernel files. PARTIALLY VERIFIED.

## 11. Wave M — Performance (measure before/after; no reliability trades)

Track: ISO/rootfs/initramfs size, idle RAM/CPU, procs, boot/gui/app/IPC/svc/net
startup, update time. Baselines live in `docs/research/*/PERFORMANCE*` (stale —
must be re-measured at this HEAD). Risks: per-connection IPC fork, polling GUIs,
xterm-per-app. Prefer lazy/event-driven/on-demand/shared. Milestone M (continuous).

## 12. Wave N — Desktop (§34.1–34.5)

Top panel/dock/launcher/search/quick-settings/notifications/workspaces/clock/
battery/net/perf widgets/theme/wallpapers exist and are QEMU-verified. Missing/
constrained: JWM is NOT a compositor (no true translucency/animations/thumbnail
previews — explicit non-goal); window stacking/focus/move/resize/min/max/
fullscreen/workspaces are JWM-native; damage/frame-scheduling/tear-prevention/
multi-monitor/GPU-sync need a real WM/compositor arch decision with measured
cost; input path INPUT→WS→APP→RENDER→DISPLAY latency unmeasured; dynamic
resolution/DPI/fractional scaling/display-hotplug unhandled; a11y tree absent;
resource controls (frame time/drops/compositor CPU/texture/wakeups) unmeasured.
Rule: degrade gracefully on weak hardware; animations optional.

## 13. Master expansion §33 — Kernel/HW/FS/Security deep tracks

- §33.1 Concurrency: SMP boot + 1/2/4/8 vCPU stress, lock-order docs, concurrent
  svc/IPC/storage/net tests, shutdown-while-busy, lockdep where available.
  Status: NOT YET VERIFIED (no lock hierarchy doc, no race/deadlock campaign).
- §33.2 Memory/VM: page-fault classes, COW/mmap/munmap/teardown/OOM, swap/reclaim
  posture, TLB-shootdown audit (use Linux, don't reimplement), 1/2/4/8 vCPU ×
  low/normal/high RAM × storage/NIC matrix, TCG+KVM. NOT YET VERIFIED.
- §33.3 HW/drivers: see §6 above.
- §33.4 FS reliability: ext4 journaling委; crash-consistency (interrupted
  writes/metadata, svc crash mid-op, simulated power loss, remount/recovery);
  atomic replace (tmp→fsync→rename→dirsync) for pkg/config/user/update/svc/
  recovery state (airapkg DB commit is atomic; other state NOT audited);
  disk-full/read-only/missing/corrupt paths. PARTIALLY VERIFIED.
- §33.5 Isolation: see §3.

## 14. §35 Kernel completion (audit, not rewrite)

Early boot, SMP, scheduler, timers, IRQ/exceptions, syscalls, procs/signals,
VM/faults/TLB, cgroups/ns/caps/seccomp, VFS/ext4/block, net/netfilter, PCI/USB,
ACPI/power/thermal, input, DRM/GPU, audio, devmgmt, logging, crash/watchdog,
initramfs, kconfig — at multiple CPU/RAM/device points. Userspace errors must
not cause uncontrolled kernel failure. Status: kernel boots in QEMU (VERIFIED);
structured kernel-facing audit matrix NOT YET VERIFIED.

## 15. §36–§37 Refactor + optimization

Dedup/dead-code/stale-debug/unneeded-deps/fragile-shell/inconsistent-API/
redundant-daemon/poll/root-priv cleanup only with regression (shell 107 +
features 52 + guest). Every optimization records BEFORE→CHANGE→AFTER→
REGRESSION; no correctness/security/reliability trades. Continuous.

## 16. §38 Failure injection (mandatory campaign)

svc crash, IPC timeout/malformed/unauthorized, net loss, DHCP/DNS fail,
disk-full, read-only FS, missing device/timeout/reset, corrupt pkg,
interrupted install/update, failed boot, missing config, invalid input/path,
app/GUI crash, mem/CPU/storage pressure, power loss. Each: detection →
containment → user-visible report → recovery → no silent corruption →
regression. Status: PARTIALLY VERIFIED (honest-unavailable paths + airapkg
atomicity tested; full campaign NOT YET VERIFIED).

## 17. §39–§41 HW program, demo, release artifacts

- HW matrix (§6). No "every computer on Earth" claims.
- Demo path BOOT→LOGIN→DESKTOP→LAUNCHER→SEARCH→FILES→TERMINAL→SETTINGS→
  SYSMON→NETWORK→SOFTWARE→NOTIFY→WORKSPACES→AUDIO→SEC/DIAG→UPDATE/RECOVERY→
  SHUTDOWN must be real (FILES/UPDATE/RECOVERY are wrappers today).
- Artifacts: ISO, tarball, kernel, initramfs, rootfs, checksums, changelog,
  arch/security/HW/perf/failure reports, recovery/install/upgrade/user/dev
  guides, API docs, limitations → `docs/release/FINAL-PRODUCTION-REPORT.md`
  with VERIFIED/SUPPORTED/PARTIALLY/HW-DEPENDENT/NOT-YET/KNOWN-LIMITATION per
  capability. NOT YET PRODUCED at this HEAD.

## 18. §42–§43 Quality bar + acceptance gate

No "zero bugs" claims. Gate requires all of: reliable boot; understood+tested
kernel integration; SMP/concurrency; memory; IRQ; DMA audit; FS crash
consistency; atomic ops; real users/sessions; real priv boundaries; reliable
storage; real networking; HW discovery + honest unsupported; functional desktop
+ WM + responsive input + scaling + real a11y arch; IPC-backed apps; safe pkgs;
verified updates; tested rollback/recovery; enforced security; diagnostics; dev
tooling; measured perf; failure injection; green regression; verified artifacts;
docs matching reality. Current HEAD satisfies: boot, IPC bus, supervised
services, honest-unavailable desktop, C0 lib, 107/107 shell. Everything else is
PARTIALLY or NOT YET VERIFIED — see rows above.

## 19. Execution order (binding)

C0 (done+verified) → C1 (done+verified) → C2 → C3 → C4 → C5 → C6 → C7 → C8 → D → E → F → G →
H → I → J → K → L → M (continuous) → N polish → §33/§35 deep audits →
§36/§37 refactor+optimize → §38 campaign → §39 matrix → demo → artifacts →
gate. Priority inside every step: correctness > security > reliability >
architecture > recovery > performance > usability > visual polish.
