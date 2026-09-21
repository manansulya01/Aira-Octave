# FINAL FEATURE MATRIX — AiraOS-Octave 1.2.0

Status scale: VERIFIED / PARTIAL / UNTESTED / UNSUPPORTED. VERIFIED only with
evidence (suite + marker).

| FEATURE | STATUS | TEST | RESULT | EVIDENCE |
|---|---|---|---|---|
| Kernel boot 7.2.2 x86_64 | VERIFIED | test-kernel | PASS | `Linux version`, no panic/oops |
| Userspace ready | VERIFIED | test-kernel | PASS | `AiraOS userspace ready` |
| Repeated boots 5x | VERIFIED | manual 5x512M | PASS | /tmp/opencode/repeat-*.log |
| Mem 256M/512M/1G/2G | VERIFIED | manual matrix | PASS | /tmp/opencode/mem-*.log |
| SMP 1/2 CPUs | VERIFIED | manual smp2 | PASS | /tmp/opencode/smp2.log |
| Init mounts/mdev/hostname | VERIFIED | autotest | PASS | boot.log markers |
| Services lifecycle | VERIFIED | test-services | PASS | status/restart/enable/disable |
| Service crash recovery | VERIFIED | autotest IPC block | PASS | failed→restart markers |
| IPC daemon + client | VERIFIED | autotest IPC block | PASS | 60+ `ipc ...` OK markers |
| IPC auth (deny/grant) | VERIFIED | autotest IPC block | PASS | denied without token |
| IPC integration (status/doctor/sysinfo) | VERIFIED | autotest | PASS | via-IPC markers |
| Storage persist round-trip | VERIFIED | test-storage | PASS | boot1 write → boot2 exists |
| Packages + rollback + attacks | VERIFIED | autotest pkg block | PASS | traversal/symlink rejected |
| Network loopback + user-net | VERIFIED | test-network | PASS | ping + lo + guest pass |
| Security boundaries | VERIFIED | autotest sec block | PASS | 700/no-suid/token root-only |
| Desktop + 9 apps | VERIFIED | test-gui | PASS | windows + content + screenshot |
| Desktop survives apps | VERIFIED | test-gui | PASS | jwm alive marker |
| Demo tour | VERIFIED | test-demo | PASS | live-demo markers |
| Doctor/diagnose | VERIFIED | autotest | PASS | DOCTOR PASS |
| Sample dev lifecycle | VERIFIED | autotest (with drive) | PASS | exact-output run |
| Release ISO boots | VERIFIED | test-iso/test-release | PASS | ISO BOOT TEST PASS |
| Checksums | VERIFIED | test-release | PASS | sha256sum -c OK |
| Human click-through JWM | PARTIAL | — | — | headless env, no input automation |
| virtio-GPU accelerated desktop | UNTESTED | — | — | no GPU on test host |
| Physical hardware | UNSUPPORTED | — | — | QEMU TCG only |
| Remote package repo | UNSUPPORTED | — | — | local repo only by design v1 |
| Login/firewall/encryption | UNSUPPORTED | — | — | documented future work |
