# AiraOS-Octave Showcase (0.2.0)

## What is it?
A bootable x86_64 OS: Linux 7.2.2 foundation + AiraOS userspace, services,
persistent storage, networking, security basics, package manager, and a real
X11/JWM graphical desktop with working applications — built reproducibly,
tested automatically, released as a bootable ISO.

## Why?
To own the full OS experience (boot → shell → desktop → apps → release) on a
stable Linux foundation instead of reimplementing kernels.

## Tour (all real, verified)
- **Boot**: SeaBIOS/grub → 7.2.2 → /init → services → shell (`AiraOS userspace ready`).
- **CLI**: `aira info/system/status/services/network/storage/users/packages/diagnose/demo/version`, guarded `shutdown/reboot`.
- **Services**: syslog/klog/net/persist supervised, start/stop/restart/enable/disable, non-root USER= proven.
- **Storage**: ext4 virtio disk, 2-boot persistence proof.
- **Network**: loopback + e1000/virtio-net + DHCP.
- **Security**: root+aira users, DAC boundaries guest-tested.
- **Packages**: local .apkg repo (build/search/info/install/verify/remove/update-check) + GUI Package Center.
- **Desktop**: JWM Aira menu (System/Utilities/Settings), tray clock + CPU load, wallpaper identity.
- **Apps**: Terminal (xterm shell), File Manager (mc), Text Editor (vi), System Monitor (live CPU/mem), Settings, Sysinfo, About, Package Center — separate processes, desktop survives exits.
- **Evidence**: `docs/research/0.2/screenshots/aira-gui-shot.xwd` (real 1024x768x24 XWD dump) + serial logs.

## Build/test/release
`scripts/build-*.sh` → `scripts/test-all.sh` (7 suites incl. ISO) → `scripts/build-release.sh 0.2.0`.
See `docs/research/0.2/DEMO_SCRIPT.md` for the 5–10 minute live demo.
