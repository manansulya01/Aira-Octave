# AiraOS-Octave Showcase (1.5.0)

## What is it?
A bootable x86_64 OS: Linux 7.2.2 foundation + AiraOS userspace, supervised
services, Aira IPC bus, persistent storage, networking, security basics,
package manager, and a real X11/JWM graphical desktop with working
applications — built reproducibly, tested automatically, released as a
bootable ISO.

## Why?
To own the full OS experience (boot → shell → bus → desktop → apps →
release) on a stable Linux foundation instead of reimplementing kernels.

## Tour (all real, verified)
- **Boot**: SeaBIOS/grub → 7.2.2 → /init → services (incl. `ipc`) → shell
  (`AiraOS userspace ready`).
- **CLI**: `aira info/system/status/services/network/storage/users/packages/
  diagnose/doctor/ipc/demo/version`, guarded `shutdown/reboot`.
- **IPC bus**: `aira-ipc ping/list/call/emit/events` over AIRA1 loopback TCP;
  `aira status` and `aira doctor` and System Information use the bus.
- **Services**: syslog/klog/net/persist/ipc supervised,
  start/stop/restart/enable/disable, non-root USER= proven, crash→failed→
  restart verified via bus.
- **Storage**: ext4 virtio disk, 2-boot persistence proof.
- **Network**: loopback + e1000/virtio-net + DHCP.
- **Security**: root+aira users, DAC boundaries guest-tested; IPC privileged
  ops require the root-only token (denied-without-token tested).
- **Packages**: local .apkg repo (build/search/info/install/verify/remove/
  update-check/rollback) + GUI Package Center.
- **Desktop**: JWM Aira menu (System/Utilities/Settings), tray clock + CPU
  load, wallpaper identity.
- **Apps**: Terminal (xterm shell), File Manager (mc), Text Editor (vi),
  System Monitor (live CPU/mem), Settings, Sysinfo (IPC-backed), About,
  Package Center — separate processes, desktop survives exits.
- **Evidence**: serial logs + `docs/research/final/` + GUI screenshot.

## Build/test/release
`scripts/build-*.sh` → `scripts/test-all.sh` (8 suites incl. demo+ISO) →
`scripts/test-release.sh 1.5.0`.
See `SHOWCASE_GUIDE.md` for the 3–5 minute live demo.
