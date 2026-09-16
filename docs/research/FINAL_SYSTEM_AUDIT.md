# AiraOS-Octave Final System Audit (0.1.0, 2026-09-16)

| Subsystem | Status | Evidence | Test | Limitations |
|---|---|---|---|---|
| Kernel build | VERIFIED | bzImage 15M GZIP #4, sha e198875..., file shows 7.2.2 PREEMPT_DYNAMIC | build-kernel.sh (incremental OK), test-kernel.sh | No clean rebuild in mission (tree prebuilt 09-12) |
| Boot/serial | VERIFIED | 3x consecutive PASS 11:42-11:44 + prior | test-kernel.sh markers, no panic/oops | TCG slow (~3s to userspace) |
| CPU/SMP/APIC/timers | VERIFIED | boot log: QEMU vCPU, TSC, HPET, IOAPIC, 1 CPU | boot markers | SMP multi-CPU not tested (1 vCPU) |
| Memory/mmap/shm | VERIFIED | MemTotal 476M, /dev/shm mounted, Xvfb SHM works | guest df/free, GUI run | OOM path untested |
| Processes/threads/sched | VERIFIED | ps/top/kill, SMP PREEMPT_DYNAMIC, JWM+X apps as separate processes | autotest ps/kill, gui windows | CPU affinity untested |
| Syscalls | VERIFIED | ELF busybox + Ubuntu X binaries run (execve/mmap/open/socket) | all guest tests | Full LTP not run |
| VFS/storage | VERIFIED | ext4 /dev/vda mount RW, 2-boot persistence | test-storage.sh PASS | No partitioning test; ISO read-only |
| Net | VERIFIED | lo ping OK, eth0 present, virtio-net user-net | test-network.sh PASS | No external Internet/DNS proof (user-net only) |
| Users/security | VERIFIED | root+aira, DAC deny/allow tested | autotest permissions | Services/GUI as root; see SECURITY.md |
| Services | VERIFIED | start/stop/restart/status/deps via pidfiles | test-services.sh PASS | No watchdog/respawn enforcement |
| aira CLI | VERIFIED | info/system/status/network/diagnose real ops | autotest aira_* | update --check only (no updater) |
| airapkg | VERIFIED | build/install/verify/remove + payload check | autotest packages | Deps warn-only; no repo signing |
| Diagnostics | VERIFIED | /var/log/airaos + aira diagnose | autotest diagnose | No crashdump |
| Graphics | VERIFIED | Xvfb :99 1024x768x24 starts, JWM manages, xterm + screenshot 3.1MB | test-gui.sh PASS | Xvfb headless; /dev/dri path untested; no real HW |
| Desktop/apps | VERIFIED (core) / PARTIAL (interactive) | JWM+Aira menu, xterm/sysinfo/about launched, mc present, survives app exit | test-gui.sh | File-mgr/settings click-through manual; keyboard/mouse via XTEST only |
| Release | VERIFIED | tarball 112M + ISO 541M + sha256, ISO boot PASS | build-release.sh, test-iso.sh | ISO text-only (GUI needs separate rootfs drive) |
| Docs | VERIFIED | 13 docs + 3 research reports | static test-userspace.sh | Dev-workflow minimal |

No fake implementations. All VERIFIED items have log evidence under logs/final-completion/.
