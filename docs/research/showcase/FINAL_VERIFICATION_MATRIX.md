# Final Verification Matrix — AiraOS-Octave 1.1.0

| area | status | evidence |
|---|---|---|
| BOOT (10/10 + 256M–2G + smp2) | VERIFIED | test-all kernel PASS; /tmp/opencode/boots/ |
| KERNEL 7.2.2 x86_64 | VERIFIED | `Linux version` marker, no panic/oops |
| INITRAMFS / /init | VERIFIED | cpio↔source in-sync; hotplug error gone (10 boots) |
| USERSPACE / users / perms | VERIFIED | autotest users/permissions/security block |
| SERVICES (no stale PID) | VERIFIED | services suite; status lines running/done |
| STORAGE (persist round-trip) | VERIFIED | storage suite boot1→boot2; fsck clean |
| NETWORK (DHCP fixed) | VERIFIED | 10.0.2.15/24 + route + DNS probes |
| PACKAGES (sandbox+atomic) | VERIFIED | 12-case matrix; mid-install rollback probe |
| SECURITY | VERIFIED | SECURITY_REPORT (5 bugs fixed + re-tested) |
| DESKTOP / tray / menus | VERIFIED | gui suite (6 windows, content checks) |
| APPLICATIONS (9 real) | VERIFIED | gui-test content markers; line audit |
| WINDOW MGMT (kill→survive) | VERIFIED | `desktop survives apps` marker |
| DEMO (`aira demo`) | VERIFIED | demo suite PASS |
| GUI screenshot | VERIFIED | evidence/desktop-1.1.0.xwd (3.1 MB xwd) |
| PERFORMANCE | VERIFIED | PERFORMANCE_REPORT (measured, not tuned) |
| SHUTDOWN / REBOOT guards | VERIFIED | autotest guard + shutdown ordering block |
| RELEASE (tested==shipped) | VERIFIED | SHA match: kernel e198875c, initramfs 82a9588b, rootfs 5569686e, ISO booted |
| Human click-through | PARTIAL | headless env, no input automation |
| virtio-GPU/DRI desktop | UNTESTED | no GPU in test host |
| Physical hardware | UNSUPPORTED | QEMU TCG only |

Nothing is marked VERIFIED without log/probe evidence above.
