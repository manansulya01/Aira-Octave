# AiraOS-Octave Architecture

## Overview

AiraOS-Octave is a minimal, bootable x86_64 Linux operating system built from scratch. It consists of:

- **Linux Kernel 7.2.2** - Custom configured for virtualization and minimal footprint
- **Initramfs Userspace** - BusyBox-based with custom AiraOS services and tools
- **Persistent Rootfs** - Optional ext4 image mounted at `/persist` for data persistence
- **Graphical Desktop** - JWM window manager with X11 (Xorg/Xvfb) and custom applications

## Boot Process

```
BIOS/UEFI
    ↓
GRUB / Direct Kernel Boot
    ↓
Linux Kernel (bzImage)
    ↓
Initramfs (initramfs.cpio)
    ↓
/init (PID 1)
    ├─ Mount /dev, /proc, /sys, /tmp, /run
    ├─ Start mdev for device nodes
    ├─ Mount /persist (if disk present)
    ├─ aira-init boot (service manager)
    │   ├─ syslog/klog (logging)
    │   ├─ persist (directories)
    │   ├─ net (network setup)
    │   ├─ ipc (message bus)
    │   ├─ device (hardware discovery)
    │   ├─ hardening (security)
    │   ├─ recovery (diagnostics)
    │   └─ user-session (user dirs)
    ├─ Auto-start GUI (if aira_gui=1)
    └─ Launch recovery shell
```

## Service Management (aira-init)

Lightweight service supervisor using pidfiles:

- **Service definitions**: `/etc/aira/services/<name>.conf`
- **Enabled services**: Symlinks in `/etc/aira/enabled/`
- **Runtime state**: `/run/aira-services/`
- **Logs**: `/var/log/airaos/<service>.log`

Service types:
- **daemon** - Long-running process (exec'd directly)
- **oneshot** - Runs once at boot

Key features:
- Dependency ordering (DEPS)
- Respawn with rate limiting (RESPAWN_MAX/RESPAWN_WINDOW)
- Resource limits (CPU, memory, file descriptors)
- Privilege separation (USER field)
- Diagnostics (aira-init diag <service>)

## IPC Bus (AIRA1 Protocol)

Local message bus on 127.0.0.1:41234:

- **Protocol**: Line-based `AIRA1|id|sender|service|method|auth|args`
- **Authentication**: Root token in `/run/aira-ipc/root.token`
- **Services**: system, storage, network, services, device, user, bus
- **Methods**: call (request/response), emit (events), events (history)
- **Security**: Privileged methods require root token

## Package Management (airapkg)

Local package format (.apkg = gzipped tar + PKGINFO):

- **Repository**: `/var/lib/airapkg/repo/`
- **Database**: `/var/lib/airapkg/installed/<name>/`
- **Security**: Path traversal protection, symlink rejection, signature support
- **Atomic transactions**: Staged install with rollback on failure
- **Operations**: install, remove, verify, rollback, build, search, update-check

## Graphical Desktop (1.3)

- **Window Manager**: JWM with Aira theme (4 workspaces, taskbar, menu)
- **Display Server**: Xorg (modesetting/virtio-gpu) or Xvfb (headless)
- **Applications**: All built with xterm + standard tools (mc, vi, etc.)
- **Keyboard Shortcuts**: Alt+F1..F9 for apps, Alt+Tab for switching

Applications:
| Shortcut | App | Description |
|----------|-----|-------------|
| Alt+F1 | Menu | Application menu |
| Alt+F2 | Terminal | xterm with copy/paste |
| Alt+F3 | Files | Midnight Commander |
| Alt+F4 | Editor | vi with Aira config |
| Alt+F5 | Settings | System configuration |
| Alt+F6 | Monitor | Real-time system stats |
| Alt+F7 | Network | Interface/DHCP management |
| Alt+F8 | Packages | Package center |
| Alt+F9 | About | System information |

## User Management (1.4)

- **Accounts**: /etc/passwd, /etc/shadow, /etc/group
- **Commands**: aira-user (adduser, deluser, passwd, groups, login)
- **Authentication**: SHA256 password hashes, shadow file
- **Session**: aira-getty (console), aira-dm (graphical login)

## Security Hardening (1.4)

Kernel sysctls applied at boot:
- kptr_restrict=2, dmesg_restrict=1
- ptrace_scope=1, unprivileged_bpf_disabled=1
- mmap_rnd_bits=28, ASLR=2
- protected_hardlinks/symlinks/fifos/regular=2
- Network: syncookies, rp_filter, no redirects/source route

Cgroups v2 for service isolation (cpu, memory, pids)

## Device Management (1.4)

- **PCI**: Enumeration via /sys/bus/pci, module auto-loading
- **USB**: Device listing via /sys/bus/usb
- **VirtIO**: Network, block, GPU, console, input, balloon
- **Input**: Keyboard/mouse via evdev
- **IPC Access**: aira-ipc call device <pci|usb|virtio|input|block|net>

## Recovery System (1.4)

aira-recovery with check/fix modes:
- Services: status, restart failed
- Storage: remount persist, fix permissions
- Network: re-run DHCP
- IPC: restart bus
- Packages: verify, rollback broken
- Graphics: restart X server

## Installation & Updates — current implementation status

**Supported host-side installer** (`scripts/install-to-disk.sh`):
- Requires root privileges on a Linux build/install host and a checksum-verified release.
- Rechecks the release checksum manifest and validates the ext filesystem image before touching the target.
- Requires an explicitly selected whole disk, refuses mounted targets, checks minimum capacity, then creates a DOS/MBR partition, ext4 filesystem, and legacy BIOS GRUB boot path.
- Interactive erase confirmation is required by default. Unattended use requires both `--yes` and `--allow-erase`.
- **Limitations:** BIOS/MBR only; no UEFI/Secure Boot path; target-disk installation has not yet been certified across physical hardware.

**In-guest installer** (`/sbin/aira-install`):
- Deliberately fails closed and does not partition or format disks. The live initramfs does not yet provide a complete, supported self-install workflow.

**Updater** (`/sbin/aira-update`):
- Reports the current version and whether a state directory exists.
- Remote check/download/install/rollback commands deliberately fail closed.
- **Not implemented yet:** a trusted signed update feed, signature verification, an atomic OS update transaction, and a verified rollback snapshot. The presence of a legacy marker or an `.apkg` file is not proof of a valid rollback image.
- Local application package transactions are handled separately by `airapkg`; they are not an OS updater.

These limitations are intentional security boundaries, not completed features. Do not advertise OS installation from the live desktop or automatic OS updates as available until their end-to-end implementations and recovery tests pass.

## Development SDK (1.5)

aira-sdk provides:
- Headers in /opt/aira-sdk/include
- Libraries in /opt/aira-sdk/lib
- Example projects and Makefile templates
- Package building integration

## Audio (1.5)

ALSA-based via aira-audio:
- Module auto-loading (virtio, hda_intel, etc.)
- Mixer control (volume, mute)
- Device enumeration
- Test tone generation

## Power Management (1.5)

aira-power supports:
- shutdown / reboot (with service cleanup)
- suspend (S3) / hibernate (S4)
- ACPI information
- Battery/thermal monitoring

## Observability (1.5)

- **aira doctor**: Health checks (kernel, services, IPC, storage, network, security)
- **aira info**: System information (JSON support)
- **aira status**: Service + mount status
- **aira diagnose**: Full diagnostic dump
- **aira log**: Unified log viewer (list, view, follow, search)

## Configuration Files

| File | Purpose |
|------|---------|
| /etc/os-release | OS identity |
| /etc/aira/services/*.conf | Service definitions |
| /etc/aira/ipc/handlers/* | IPC service handlers |
| /etc/jwm/aira-jwmrc | Window manager config |
| /etc/hostname | System hostname |
| /etc/shadow | Password hashes |
| /etc/fstab | Filesystem table |
| /etc/resolv.conf | DNS configuration |

## Directory Structure

```
/                           # Initramfs root (read-only)
├── init                    # PID 1 init script
├── bin/                    # BusyBox symlinks
├── sbin/                   # System binaries (aira-init, aira-ipcd, etc.)
├── usr/bin/                # User commands (aira, airapkg, aira-*, etc.)
├── etc/                    # Configuration
│   ├── aira/
│   │   ├── services/       # Service definitions
│   │   ├── ipc/handlers/   # IPC handlers
│   │   └── enabled/        # Enabled service symlinks
│   ├── passwd/shadow/group # User database
│   └── udhcpc/             # DHCP client script
├── var/
│   ├── log/airaos/         # Service logs
│   ├── lib/airapkg/        # Package database
│   └── run/                # Runtime state
└── persist/                # Mount point for persistent disk
```

## Building

```bash
# Build kernel
scripts/build-kernel.sh

# Build initramfs
scripts/build-initramfs.sh

# Build persistent rootfs (optional)
scripts/build-rootfs.sh 512

# Create release
scripts/build-release.sh 1.5.0

# Run tests
scripts/test-all.sh
scripts/test-features.sh
```

## Testing

Automated test suite covers:
- Kernel boot
- Userspace initialization
- Service management
- IPC bus
- Network/Storage
- GUI applications
- Package operations
- Recovery scenarios

Run with: `scripts/test-all.sh` (host) or `scripts/test-full.sh` (guest)