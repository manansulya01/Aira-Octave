# AiraOS-Octave — Complete Capability Matrix

Date: 2026-10-21. Source of truth for what is implemented, tested, and missing.

> Audit note (2026-10-21): this matrix contains older evidence rows and must not be read as a fresh test run. The current full-build/QEMU workflow is the acceptance gate for the latest source. Confirmed changes since the original matrix include the cmdline safe-mode path, the GRUB/ISO release path, support-bundle tests, installer safety guards, and a fail-closed OS updater. The in-guest installer and remote OS update transaction remain unavailable; the host-side installer is BIOS/MBR only.
Status vocabulary: IMPLEMENTED+TESTED / IMPLEMENTED / PARTIAL / EXPERIMENTAL /
UNTESTED / BROKEN / MISSING / BLOCKED / DEFERRED / PHYSICAL-HARDWARE-UNVERIFIED.
Evidence column names a concrete artifact (log/test/doc) — not an assertion.

## A. Boot and platform
| Capability | State | Evidence |
|---|---|---|
| BIOS boot (SeaBIOS) | IMPLEMENTED+TESTED | every logs/final-completion/final-autotest*.log boots via SeaBIOS |
| UEFI boot | MISSING | no UEFI bootloader path in scripts/ or rootfs |
| Bootloader integration (GRUB BIOS/ISO) | IMPLEMENTED; latest release gate pending | `scripts/build-release.sh`, `scripts/test-iso.sh`; UEFI remains missing |
| Kernel cmdline | IMPLEMENTED+TESTED | `aira_autotest=1`, `aira_guitest=1` exercised in guest tests |
| initramfs | IMPLEMENTED+TESTED | scripts/build-initramfs.sh, PASS each build |
| Rootfs discovery/mount (/persist, ext4) | IMPLEMENTED+TESTED | "persist" IPC + doctor `release persistence PASS` |
| Emergency boot / recovery target | PARTIAL | `aira-recovery` runs inside guest; no separate recovery boot target |
| Safe mode | IMPLEMENTED; latest release gate pending | `scripts/test-safe-mode.sh` checks `aira_safe=1` and recovery shell markers |
| Boot diagnostics / boot-log / failure detection | PARTIAL | boot services.log + `init` OK checks; no failure classification |
| Boot timeout handling / watchdog | MISSING | no watchdog driver wiring in /init |
| HW discovery (cpu/mem/pci/usb/ac) | IMPLEMENTED+TESTED | `aira platform` guest checks (model name, vendor=, CPU0) |
| ACPI / power states / suspend-resume | PARTIAL | ACPI present (dmesg PNP0A03); no suspend/resume test |
| NUMA awareness | MISSING | single-vCPU QEMU only |

## B. Kernel capabilities
| Capability | State | Evidence |
|---|---|---|
| Processes/threads/signals/timers/mmap/VFS/net stack | IMPLEMENTED (Linux) | kernel 7.2.2 boots, all guest tests run |
| Namespaces/cgroups/seccomp | IMPLEMENTED (Linux) | doctor: `cgroups PASS mounted`, `namespaces available`, `seccomp kernel reports support` |
| SMP/PSU states under stress | UNTESTED | single vCPU only in QEMU runs |
| Crash handling / kdump / panic policy | PARTIAL | `reboot: Power down` clean; no kdump |
| Tracing/debugging (ftrace, perf) | MISSING at Aira layer | no consumer tooling |
| Sysctl hardening posture | PARTIAL | `hardening.conf` shipped for svc manager; kernel audit pending |

## C. Hardware and device platform
| Capability | State | Evidence |
|---|---|---|
| PCI/USB/block/net discovery | IMPLEMENTED+TESTED | `device` IPC handler + `aira platform` output in guest |
| mdev/udev policy | PARTIAL | `mdev.conf` present; hotplug policy absent |
| Input devices (kbd/mouse/touch) | PARTIAL | `aira-device-setup` + guiinput tests; no hotplug ACL |
| Display/GPU (virtio-gpu, Xorg/Xvfb) | PARTIAL | `test-gui.sh`, `check-gui-libs.sh`; DRM WARN in headless doctor |
| Audio | PARTIAL | `aira-audio` honest UNSUPPORTED on QEMU (D9) |
| Ethernet (e1000/virtio-net) | IMPLEMENTED+TESTED | `link:eth0 ONLINE` in final-autotest9.log (2026-10-06) |
| Wi-Fi/Bluetooth | MISSING | no wireless hardware in image; doctor marks UNSUPPORTED |
| Cameras/sensors/printers/gamepads | MISSING | no drivers wired into Aira layer |
| Firmware loading | PARTIAL | `regulatory.db` load failure visible in dmesg (non-fatal) |
| Hotplug/unplug recovery campaign | MISSING | not tested |

## D. Storage
| Capability | State | Evidence |
|---|---|---|
| /persist on /dev/vda ext4 | IMPLEMENTED+TESTED | storage guest tests, write+survives reboot |
| Partition discovery (GPT/MBR) | PARTIAL | fdisk present in busybox; no parser tooling at Aira layer |
| tmpfs/proc/sysfs/devtmpfs mounts | IMPLEMENTED+TESTED | `pseudo-fs PASS /proc /sys /dev present` |
| overlayfs | MISSING | not wired anywhere |
| Filesystem health/fsck path | PARTIAL | `aira-recovery` mentions fsck; no tested run |
| Disk usage/quota | PARTIAL | `df` checks; no quota enforcement |
| Encryption (dm-crypt) | MISSING | architecture doc only |
| Snapshots | MISSING | no btrfs/ZFS/LVM path |
| Backup/restore tooling | PARTIAL | pkg rollback exists; no system image backup |
| Interrupted-write/power-loss consistency | PARTIAL | airapkg DB commit atomic; rest NOT audited (§33.4) |
| Atomic-replace pattern for all state | PARTIAL | airapkg yes; user/settings/svc state not uniformly audited |

## E. User and identity
| Capability | State | Evidence |
|---|---|---|
| users/groups/passwd/shadow, uid mgmt, lock/unlock | IMPLEMENTED+TESTED | usertest3.log PASS 50+ checks (2026-10-06) |
| Salted password hashing | IMPLEMENTED+TESTED | usertest: same password → different hash |
| Account deletion, home removal, passwd survives | IMPLEMENTED+TESTED | usertest3.log |
| Privilege escalation boundaries (uid=aira service) | IMPLEMENTED+TESTED | guest autotest: unprivileged service run OK |
| ACLs/capabilities per user | MISSING | no ACL tooling |
| Credential storage | PARTIAL | shadow mode 640 verified in doctor |
| Lockout/rate limiting, audit logging of auth | MISSING | not implemented |
| Authorization beyond root-token | PARTIAL | services/net privileged-methods gate; desktop still effectively root |

## F. Init and service management
| Capability | State | Evidence |
|---|---|---|
| Daemon/oneshot, deps, ordering | IMPLEMENTED+TESTED | services boot order in services.log |
| Respawn limits, crash recovery | IMPLEMENTED+TESTED | autotest crashed-service recovery OK |
| Enable/disable/mask/manual start/stop | IMPLEMENTED+TESTED | autotest enable/disable OK |
| Status/logs/diag verbs | IMPLEMENTED+TESTED | `aira-init status` in doctor |
| Health checks, timeouts, resource limits | PARTIAL | respawn limits only; no cgroup quota |
| Boot targets (recovery/emergency) | MISSING | single boot path |
| Parallel startup | MISSING | boot order strictly sequential |

## G. IPC and control plane
| Capability | State | Evidence |
|---|---|---|
| AIRA1 IPC v1, 127.0.0.1:41234 | IMPLEMENTED+TESTED | bus PASS in doctor + autotest |
| Root-token DAC auth, mode 600 | IMPLEMENTED+TESTED | ipc token perms tests |
| 8 KiB line cap, 10s handler timeout | IMPLEMENTED+TESTED | ipc timeout test |
| Typed requests/validation/structured errors | IMPLEMENTED+TESTED | bad service name rejected etc. |
| Privileged method gating (PRIV_METHODS) | IMPLEMENTED+TESTED | `ipc denied services.stop without token` |
| Event subscribe/async | MISSING | sync request/response only |
| Unix-socket transport | MISSING | TCP loopback only |
| Audit logging of privileged calls | MISSING | trace.log partial only |
| Protocol version compat handling | PARTIAL | `v=2` in caps; no negotiation test |

## H. Networking
| Capability | State | Evidence |
|---|---|---|
| Loopback | IMPLEMENTED+TESTED | ping loopback OK in every boot |
| Ethernet + DHCP (user-net) | IMPLEMENTED+TESTED | final-autotest9.log: link:eth0 ONLINE after fix 2026-10-06 |
| Static IPv4 / routes / DNS setdns | IMPLEMENTED+TESTED | test-net.sh 115/115 host |
| Persisted network profile + apply | IMPLEMENTED+TESTED | guest-netpersist + fixed profile=absent bug |
| IPv6 | MISSING | net caps list no v6 verbs |
| DNS caching / resolver verification | PARTIAL | resolution WARN until external confirmed |
| Wi-Fi / WPA | MISSING | no wireless hardware |
| Firewall/NAT (netfilter) | MISSING | doctor doesn't check; netfilter present in kernel only |
| VPN / net namespaces tooling | MISSING | kernel feature only |
| Network diag end-to-end (DNS→TCP→HTTPS) | PARTIAL | `aira-net diag` resolves example.com in guest |
| Time sync (NTP) | MISSING | no ntpd/chrony |

## I. Security
| Capability | State | Evidence |
|---|---|---|
| Loopback-only bus, root token, PRIV_METHODS | IMPLEMENTED+TESTED | autotest |
| airapkg traversal/symlink/PKGINFO guards | IMPLEMENTED+TESTED | autotest pkg attack-rejection tests |
| shadow mode 640, ipc token 600, dev-null perms | IMPLEMENTED+TESTED | doctor security rows |
| `su`-based unprivileged services | IMPLEMENTED+TESTED | services |
| Seccomp/capabilities/namespace enforcement matrix | MISSING | only "kernel reports support" doctor row |
| MAC policy (AppArmor/SELinux) | MISSING | no policy loaded |
| Firewall | MISSING | no netfilter rules configured |
| Package signatures (cryptographic) | MISSING | sha256 sidecar only — documented risk |
| Verified/atomic updates | PARTIAL | `aira-update` exists, failed-update rollback untested |
| Secure boot / TPM / disk encryption | MISSING | not integrated |
| Exploit mitigation posture (PIE/RELRO/stack) | UNTESTED | no audit script |
| Audit logging framework | PARTIAL | doctor security rows; no turnkey audit trail |

## J. Package management
| Capability | State | Evidence |
|---|---|---|
| airapkg build/search/info/install/remove/verify | IMPLEMENTED+TESTED | autotest pkg section |
| Atomic staged install + rollback | IMPLEMENTED+TESTED | rollback autotest rows |
| Dependency/conflict handling | PARTIAL | "missing dep warns" row only |
| Corrupt package rejection | IMPLEMENTED+TESTED | autotest |
| Transaction log | IMPLEMENTED | autotest tx-log UNKNOWN→ present? (see doctor row) |
| Remote repositories | MISSING | local repo only |
| Signature enforcement | MISSING | sha256 sidecar only |
| Downgrade handling, orphan cleanup | MISSING/UNTESTED | no tests |
| Reproducible package builds | PARTIAL | PKGINFO+Makefile path via aira-sdk |

## K. Update and recovery
| Capability | State | Evidence |
|---|---|---|
| `aira-update` status surface | IMPLEMENTED; remote update operations BLOCKED | `scripts/test-update-safety.sh` confirms check/download/install/rollback fail closed without trusted feed |
| Signed OS update transaction | MISSING | No trusted signed feed, signature verifier, atomic switch, or verified rollback transaction |
| Failed update → rollback | MISSING | No OS update transaction exists yet; legacy markers are not trusted snapshots |
| Recovery environment via cmdline | PARTIAL | `aira-recovery` in guest only |
| Migration scripts / config preservation | MISSING | no version-compat path |

## L. Desktop / graphical platform
| Capability | State | Evidence |
|---|---|---|
| JWM WM + themes + wallpapers + workspaces | IMPLEMENTED+TESTED | test-gui.sh, JWM-native verified 2026-10-04 |
| Xorg or Xvfb selection | IMPLEMENTED+TESTED | `aira-session --auto` |
| Panel/dock/launcher/quick-settings/notify | IMPLEMENTED+TESTED | D-section tests |
| True compositor / translucency / tear-free | MISSING (explicit non-goal) | JWM row in §N |
| Multi-monitor / scaling / hotplug | MISSING | not handled |
| Session lock / logout / graphical login | PARTIAL | aira-dm/session-mgr exist, lock unverified |
| Apps integrated with control plane | PARTIAL | C0 lib partial adoption (gui/aira-settings, aira-sysinfo) |

## M. Accessibility
| Capability | State | Evidence |
|---|---|---|
| Keyboard nav of WM/launcher | PARTIAL | JWM keys, launcher --text |
| High-contrast themes / font scaling | PARTIAL | themes exist, not specifically a11y-audited |
| Focus indicators / reduced motion / color-independent status | MISSING | no implementation |
| Screen reader architecture/tree | MISSING | never claim without real tree |

## N. Core applications
| Capability | State | Evidence |
|---|---|---|
| File manager (mc) | IMPLEMENTED | C1 files IPC + mc wrapper |
| Terminal (xterm) | IMPLEMENTED | C3 terms verified |
| Text editor (vi) | IMPLEMENTED | base image |
| System monitor | IMPLEMENTED+TESTED | C4 sysmon |
| Settings | IMPLEMENTED+TESTED | C2 |
| Package manager UI | PARTIAL | `aira-pkgcenter --text`; GUI wrapper thin |
| Network manager UI | PARTIAL | `aira network` CLI; GUI wrapper thin |
| Disk/process/task manager GUI | MISSING at Aira layer | mc/top/xterm only |
| Archive manager / calculator / media / image viewers / PDF viewer | MISSING | no shipped apps |
| Software updater GUI | MISSING | CLI only |

## O. Developer platform
| Capability | State | Evidence |
|---|---|---|
| aira-sdk + samples/hello-aira | IMPLEMENTED+TESTED | samples build (build-samples.sh) |
| Makefile-based pkg build | IMPLEMENTED+TESTED | airapkg build rows |
| IPC API docs | PARTIAL | example doc present; no full API reference |
| Debugger/profiler/tracing tooling | MISSING | no gdb/perf in image |
| Git presence | MISSING in guest | host-only |
| SDK headers install | MISSING | no sysroot /usr/include tree |

## P. Virtualization and containers
| Capability | State | Evidence |
|---|---|---|
| Namespaces/cgroups kernel support | IMPLEMENTED (Linux) | doctor rows |
| Container runtime/tooling | MISSING | no podman/runc in image |
| VM management (qemu/kvm guest) | MISSING | Aira itself runs under QEMU; no in-OS VMM |
| Sandboxed execution tooling | MISSING | no bwrap/firejail equivalent |

## Q. System administration
| Capability | State | Evidence |
|---|---|---|
| CLI admin: users/services/pkgs/storage/net/logs | IMPLEMENTED+TESTED | aira-* CLIs + guest suites |
| Unified GUI admin center | PARTIAL | settings only; no unified console |
| Process manager CLI | PARTIAL | ps/top via busybox |

## R. Observability
| Capability | State | Evidence |
|---|---|---|
| Service/kernel/ipc logs on disk | IMPLEMENTED+TESTED | /var/log/airaos/* |
| aira log/doctor/info/diagnose | IMPLEMENTED+TESTED | C7 verified |
| Structured logs (levels, rotation) | MISSING | plain text only |
| Crash report bundles | MISSING | none |
| Metrics/perf counters exporter | MISSING | ad-hoc |
| Diagnostic/support bundle generator | MISSING | none |

## S. Performance
| Capability | State | Evidence |
|---|---|---|
| Boot time measurement | PARTIAL | boot-log byte count only; no timing metric collected |
| IPC latency | UNTESTED | no benchmark |
| FS throughput / storage latency | UNTESTED | none |
| Network throughput / DNS latency | UNTESTED | none |
| GUI/app startup | UNTESTED | none |
| Automatic regression baselines | MISSING | no PERF suite |

## T. Reliability / failure injection
| Capability | State | Evidence |
|---|---|---|
| airapkg corrupt/traversal rejection | IMPLEMENTED+TESTED | autotest |
| IPC crash/malformed/unauthorized | IMPLEMENTED+TESTED | autotest ipc section |
| Honest UNSUPPORTED for audio/GPU/wifi | IMPLEMENTED+TESTED | doctor WARN rows |
| Service crash recovery | IMPLEMENTED+TESTED | autotest |
| Net loss / DHCP fail / DNS fail | PARTIAL | aira-net-setup best-effort documented; not failure-campaign logged |
| Corrupt config / corrupt pkg metadata | PARTIAL | pkg guards; no config corruption test |
| Disk full / read-only / missing device | UNTESTED | §33.4 partial |
| Interrupted update / failed boot / power loss | UNTESTED | no campaign |
| Memory/CPU pressure campaign | MISSING | none |

## U. Installation and distribution
| Capability | State | Evidence |
|---|---|---|
| Bootable ISO | IMPLEMENTED; latest source gate pending | GRUB ISO generation + `scripts/test-iso.sh`; verify current workflow before release |
| `aira-install` in initramfs | BLOCKED / fail-closed | Explicitly refuses disk changes; use host-side `scripts/install-to-disk.sh` |
| Host-side BIOS/MBR install | IMPLEMENTED; physical boot unverified | `scripts/install-to-disk.sh`; preflight guards tested, full disposable-disk install still needs integration coverage |
| Live environment | MISSING | no live mode |
| First-boot wizard / user+timezone+locale setup | MISSING | none |
| Release channels / signed artifacts / checksums | PARTIAL | MANIFEST + test-manifest.sh; no repo signing |
| Reproducible-build evidence | MISSING | logs exist per build; no reproducibility proof |
| Upgrade matrix between releases | MISSING | none |

## V. AI platform
| Capability | State | Evidence |
|---|---|---|
| Local inference / model mgmt / APIs | MISSING | no AI subsystem in repo |
| Optional/privacy-controlled integration arch | MISSING | architecture note only |

## W. Documentation
| Capability | State | Evidence |
|---|---|---|
| ARCHITECTURE / BUILD / SECURITY / TESTING / BOOT docs | IMPLEMENTED | docs/*.md |
| WAVE-C architecture + MASTER production plan | IMPLEMENTED | docs/architecture/*.md |
| CLI/API reference per subsystem | PARTIAL | IPC example doc only |
| Troubleshooting docs | PARTIAL | TROUBLESHOOTING.md short |
| Test methodology per subsystem | PARTIAL | TESTING.md short |
| Known-limitations register | PARTIAL | this matrix + MASTER §42 |

## Cross-cutting notes
- C0–C7 wave rows verified PASS with dated guest logs under `logs/final-completion/`
  (autotest logs dated 2026-10-04 through 2026-10-06).
- NIC race fixed 2026-10-06: `aira-net-setup` now polls for a non-lo netdev and
  falls back to DHCP when a persisted profile leaves the link DOWN; verified by
  `logs/final-completion/final-autotest9.log` → `===== GUEST AUTOTEST PASS =====`.
- Fresh-image rule honored for every state change above (initramfs rebuild +
  boot + guest test before any PASS claim).
- PHYSICAL-HARDWARE-UNVERIFIED applies to §C rows marked MISSING/PARTIAL where
  hardware is genuinely unavailable.
