# Full Test Report — AiraOS-Octave 1.1.0 (2026-09-19)

Harness: `scripts/test-all.sh` (8 suites) + `scripts/test-release.sh 1.1.0`
+ manual probes below. Kernel 7.2.2 x86_64, QEMU 10.2.1 (TCG, no KVM).

## Suite results (final tree)
- kernel: PASS (Linux version, rdinit, userspace-ready markers, no panic/oops)
- userspace-static: PASS (layout + shell syntax; informational
  `MISS initramfs/var/log/airaos` only — that dir is created at boot by /init)
- services: PASS (syslog/klog running single-instance, oneshot done,
  restart/crash/recover/stop/disable, ordered shutdown)
- storage: PASS (two-boot persistence marker round-trip on aira-rootfs.img)
- network: PASS (loopback + full autotest; DHCP fix verified separately)
- gui: PASS (6 client windows, sysinfo/sysmon/netman/mc/about content,
  screenshot 3148907 bytes, desktop survives)
- demo: PASS (`aira_demo=1` guided tour)
- iso: PASS (release 1.1.0 ISO grub-boot to userspace)
- TEST-ALL: PASS. RELEASE PIPELINE (build+sha256+ISO boot): PASS.

## 10 consecutive clean boots: 10/10 PASS
Each: `aira_autotest=1` → GUEST AUTOTEST PASS + `AiraOS userspace ready` +
no panic. Logs: `/tmp/opencode/boots/boot-{1..10}.log`.

## CPU/memory matrix (all PASS, autotest green)
- 256M / 512M / 1G / 2G, 1 CPU; 1G with `-smp 2` (SMP kernel, MemTotal 991768 kB).
- No physical-hardware claim (QEMU TCG only).

## Targeted probes (this session)
- DHCP (S1): boot-time `inet 10.0.2.15/24` + route + DNS; `aira network dhcp`
  RC=0. VERIFIED.
- airapkg perms (S2): 755→755, 600→600. VERIFIED.
- airapkg stale-file (S5): `removed stale /etc/app.conf`, V2 content live. VERIFIED.
- airapkg atomicity: mid-install failure → RC=1, partial removed, DB clean. VERIFIED.
- PKGINFO code-exec canary: not executed. VERIFIED.
- auto-GUI `aira_gui=1`: Xvfb :0 + `jwm -f /persist/etc/jwm/aira-jwmrc`,
  X socket + root window live (previously: "no session found" — init checked
  /persist before mounting it; block moved after persist mount + services). VERIFIED.
- Rootfs fsck: clean (`e2fsck -n -f`, state clean). A transient in-guest
  EXT4 I/O-error burst was observed once during an UNSYNCED `poweroff -f`
  with fontconfig writes in flight; image verified healthy afterwards and
  storage tests re-passed. Always `sync` before hard poweroff.
