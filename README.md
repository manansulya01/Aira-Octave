# AiraOS-Octave 1.2.0

Bootable x86_64 OS: Linux 7.2.2 + AiraOS userspace + supervised services +
Aira IPC bus (AIRA1) + persistent ext4 + networking + package manager with
rollback + X11/JWM desktop + applications + automated tests + reproducible
release.

## Quick start
- Build: `bash scripts/build-samples.sh`, `bash scripts/build-initramfs.sh`, `bash scripts/build-gui.sh`, `bash scripts/build-rootfs.sh 512`
- Boot text: `bash scripts/boot-qemu.sh --mem 512M --timeout 35 --log logs/boot.log`
- Boot GUI/persist: add `--drive aira-rootfs.img --mem 1G`, in guest run `aira-session`
- Demo: `bash scripts/demo.sh` (or `scripts/demo.sh --iso --gui`) — see `SHOWCASE_GUIDE.md`
- IPC: in guest, `aira ipc ping hello`, `aira ipc list`, `aira doctor`
- Test: `bash scripts/test-all.sh` (kernel/userspace/services/storage/network/gui/demo/iso)
- Release: `bash scripts/test-release.sh 1.2.0` (builds + checksums + boots ISO)

## What's inside
- Kernel 7.2.2 GZIP/SMP/PREEMPT_DYNAMIC, virtio (blk/net/gpu/input), e1000, ext4, DRM.
- Userspace: BusyBox, /init, aira CLI (info/system/status/services/network/
  storage/users/platform/diagnose/doctor/ipc/demo/...), airapkg
  (search/info/install/remove/verify/rollback/update-check), service manager
  (start/stop/restart/status/enable/disable/USER/shutdown), users (root+aira).
- IPC bus: `aira-ipcd` daemon + `aira-ipc` client (AIRA1 over loopback TCP) +
  handlers (bus/services/system/storage/network) with root-token auth for
  privileged ops; `aira status` and `aira doctor` and System Information use
  the bus (with direct fallback).
- Desktop: Xvfb/Xorg + JWM (Aira menu), Terminal, File Manager, Text Editor,
  System Monitor, Settings, Network Manager, Package Center, Sysinfo, About.
- Dev: C sample app with packaged/host-to-guest workflow (see DEVELOPER_GUIDE.md).

## Hardware
QEMU verified (see HARDWARE_COMPATIBILITY.md). Real HW untested.

## Limitations
- Core services/desktop run as root (USER= mechanism proven; separation future work).
- No login/firewall/encryption; local package repo only; user-net networking.
- IPC binds all interfaces at the nc level (loopback-only not enforceable with
  this BusyBox nc); QEMU user-net exposes no guest ports by default, and
  privileged bus methods require the root-only token.
- See `docs/research/final/KNOWN_LIMITATIONS.md` for the full honest list.
