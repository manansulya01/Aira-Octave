# Post-1.0 Architecture Audit (1.0.0 @ ddce83dfd)

Method: source inspection + kernel-config audit + executed test logs
(logs/final-completion/* 2026-09-18). No source modified for this file.

## BOOT path
SeaBIOS → grub2 (ISO) or QEMU `-kernel` direct → Linux 7.2.2 → initramfs
→ /init (rdinit) → mounts/hostname/mdev/persist → aira-init boot →
serial shell (and Xvfb/JWM on demand). Recovery = the shell itself; GUI can
never block it (/init execs sh last; session is optional).
- Aira-specific: /init, service hook, demo/autotest hooks.
- Linux-provided: bootloader protocol, decompression, initramfs unpack.
- Tested: YES (every suite boots; ISO boots via grub).

## KERNEL deep audit (config = linux-7.2.2/.config, 80a13a5f)
For each: IMPLEMENTED BY / TESTED / EVIDENCE / LIMITATION / RISK / NEXT.

- Boot (GZIP, x86_64, protocol 2.15): Linux. TESTED (all boots). EVID: file(1)
  + serial banner. LIMIT: direct-boot primary, grub secondary. RISK: low.
  NEXT: none.
- SMP (CONFIG_SMP=y, NR_CPUS=64, 1 vCPU observed): Linux. TESTED single-CPU
  only (BogoMIPS, 1 node). LIMIT: multi-vCPU never booted. RISK: low (defconfig
  SMP). NEXT: boot -smp 2 and assert cpu count.
- Scheduler (PREEMPT_DYNAMIC, HZ=1000, NO_HZ_IDLE, HRTIMERS): Linux. TESTED
  implicitly (concurrent X clients + services). EVID: qemu logs, GUI windows.
  LIMIT: no RT/latency measurement. RISK: low. NEXT: none required.
- Task/process mgmt: Linux. TESTED (fork/exec/ps/kill in autotest + apps).
- VM/physical/paging/SLUB: Linux (SLUB=y, THP=n, NUMA=y single-node). TESTED
  implicitly (476MB userspace, X mmap). EVID: MemTotal 476656 kB. LIMIT: no OOM
  test, no mmap stress. RISK: low. NEXT: optional OOM-score test (risky, skip).
- VFS/block/loop/initrd: Linux. TESTED (cpio unpack, ext4 mount, loop=y unused).
- Filesystems: ext4/iso9660/vfat/proc/sysfs/tmpfs/devtmpfs(+mount)=y;
  overlay/squashfs=n. TESTED: ext4 RW + persistence; proc/sys/dev used by /init.
  LIMIT: no overlay (container future unaffected — namespaces exist).
- Networking (NET/INET/IPV6/NETFILTER/UNIX/PACKET/9P=y): Linux. TESTED: lo,
  e1000, virtio-net, DHCP path, TCP loopback via nc. EVID: network-*.log.
  LIMIT: no IPv6 traffic test, no firewall rules shipped. RISK: low.
- IPC (SYSVIPC/POSIX_MQUEUE=y, pipes/sockets): Linux. TESTED: pipes (suite pipes),
  TCP loopback (nc). LIMIT: no SysV SHM/msg test, no Unix-socket test. RISK: low.
- Signals/timers/IRQs: Linux. TESTED: IO-APIC routing table in platform log
  (timer/i8042/ttyS0/rtc/acpi/eth0/ata), kill -9 detection in services.
- ACPI/PCI/device model: Linux (ACPI=y, PCI+MSI=y). TESTED: enumeration
  (6 PCI devs), S5 poweroff every autotest. EVID: platform listing.
- TTY/serial (8250+console=y): Linux. TESTED: all serial evidence. No fb console
  (FB=n) — serial-only console. LIMIT/RISK: none for target.
- Framebuffer/graphics (FB=n, DRM=y, VIRTIO_GPU via DRM_VIRTIO_GPU=y,
  BOCHS/SIMPLEDRM=n, FBDEV_EMULATION=n): Linux. TESTED: Xvfb path only;
  /dev/dri absent on std-VGA path (honestly reported). LIMIT: no KMS/FB console,
  no GPU-tested path. RISK: medium for "real graphics" claims — mitigated by
  honest PARTIAL status. NEXT: boot -vga virtio and assert /dev/dri + Xorg start.
- Input (EVDEV, i8042, ATKBD, PS2 mouse=y): Linux. TESTED: kernel detection;
  X input via XTEST only (headless). LIMIT: no physical key/mouse events.
- Security (SECURITY=y, SELINUX=y compiled, APPARMOR=n, SECCOMP(+FILTER)=y,
  KEYS/AUDIT=y, MODULES=y): Linux provides, Aira barely uses. TESTED: DAC only.
  LIMIT: no policy, no seccomp filters in Aira code, modules unused. RISK: medium
  only if threat model grows. NEXT: seccomp for airapkg-extracted payloads (0.x?).
- Namespaces/cgroups (all=y): Linux, present but UNUSED by Aira. OPPORTUNITY:
  service/app sandboxing without new kernel work.
- Capabilities: Linux (default file caps; Aira uses none — no setuid at all).
- Modules: enabled, none shipped/loaded (all needed drivers built-in). EVID:
  no modprobe use in logs. LIMIT: none.
- Logging/panic (PRINTK/BUG=y, SYSRQ=y, KEXEC=y but KEXEC_FILE=n, CRASH_DUMP=y,
  IKCONFIG=n): Linux. TESTED: full dmesg capture, zero panic/oops across all
  runs. LIMIT: no kdump capture (CRASH_DUMP=y but no kexec userspace), no
  IKCONFIG (provenance via tracked .config instead — adequate).
- Correction to older docs: virtio-GPU arrives via CONFIG_DRM_VIRTIO_GPU
  (there is no CONFIG_VIRTIO_GPU symbol); SELinux is compiled but unenforced
  (no policy/tools) — do not claim MAC.

## USERSPACE map
| Component | Origin | Tested |
|---|---|---|
| /init (mounts, hostname, mdev, persist, services, shell) | Aira custom (~90 lines sh) | YES (every boot) |
| aira-init supervisor (pidfiles, deps, USER=, enable, shutdown order) | Aira custom | YES (lifecycle incl. crash/recovery) |
| aira CLI (14 subcommands) | Aira custom | YES (each exercised in autotest) |
| airapkg (tar.gz+PKGINFO, DB, rollback) | Aira custom | YES (incl. corrupt/invalid/rollback) |
| users/passwd/group, DAC | Linux + Aira files | YES (deny/allow) |
| net setup (ip/udhcpc) | BusyBox + Aira script | YES |
| ext4 persist | Linux + Aira mount/fstab | YES (2-boot) |
| X servers/WM/apps | External Ubuntu debs + Aira configs/scripts | YES (headless Xvfb) |
| shell/utils/editor (sh/vi/ps/...) | BusyBox (95 applets) | YES (daily use in tests) |
| libc/loader for dynamic binaries | External (Ubuntu glibc staged) | YES (sample app runs) |

## DEVELOPER PLATFORM map
- Compiler/linker/debugger/Git: HOST-ONLY (gcc on build machine). Guest: NONE.
- Headers/SDK: NONE in guest. IPC: Linux (pipes/sockets, TCP proven).
- Packaging: airapkg + documented sample workflow (proven end-to-end).
- Docs: DEVELOPER_GUIDE.md accurate (states cross-dev).

## Tested-status legend used here
TESTED = executed in guest with log evidence. Absence of a row test = gap,
listed under LIMITATION, never upgraded.
