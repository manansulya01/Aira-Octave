# AiraOS-Octave

A minimal, bootable x86_64 Linux operating system built from scratch.

## Features

### 1.3 Desktop Experience
- **JWM Window Manager** - Custom theme, 4 workspaces, taskbar, application menu
- **Terminal** - xterm with copy/paste, Alt+F2
- **File Manager** - Midnight Commander integration, Alt+F3
- **Text Editor** - vi with syntax highlighting, Alt+F4
- **Settings** - System/Display/Network/Storage/Users/Security/Apps/About, Alt+F5
- **System Monitor** - Real-time CPU/Memory/Process/Storage/Network, Alt+F6
- **Network Manager** - Interfaces, DHCP, Routes, DNS, Alt+F7
- **Package Center** - Search, Install, Remove, Verify, Rollback, Alt+F8
- **About** - System information, Alt+F9

### 1.4 Platform Hardening
- **User Management** - Accounts, groups, passwords, login/session
- **Security** - Kernel hardening, cgroups, seccomp, shadow passwords
- **Service Manager** - Dependencies, respawn, resource limits, diagnostics
- **IPC Bus** - AIRA1 protocol, request/response, events, service discovery
- **Device Management** - PCI, USB, VirtIO, input discovery
- **Recovery** - Check/fix services, storage, network, packages, graphics

### 1.5 Flagship
- **Installer** - Disk partitioning, filesystem, bootloader, user creation
- **Updater** - Atomic updates with snapshot rollback
- **SDK** - Headers, libraries, examples, package building
- **Audio** - ALSA mixer, device enumeration, test tones
- **Power** - Shutdown, reboot, suspend, hibernate, ACPI
- **Observability** - Doctor, info, status, diagnose, unified logs

## Quick Start

### Boot in QEMU (Live)
```bash
qemu-system-x86_64 \
    -machine q35,accel=kvm \
    -cpu host \
    -m 1G \
    -kernel bzImage \
    -initrd initramfs.cpio \
    -append "console=ttyS0 aira_gui=1" \
    -serial stdio
```

### Boot with Persistence
```bash
# Create disk image
qemu-img create -f raw aira-rootfs.img 2G

# Boot with disk
qemu-system-x86_64 \
    -machine q35,accel=kvm \
    -cpu host \
    -m 1G \
    -kernel bzImage \
    -initrd initramfs.cpio \
    -drive file=aira-rootfs.img,format=raw,if=virtio \
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
    -append "console=ttyS0 aira_gui=1" \
    -serial stdio
```

### Keyboard Shortcuts
| Key | Action |
|-----|--------|
| Alt+F1 | Main menu |
| Alt+F2 | Terminal |
| Alt+F3 | File Manager |
| Alt+F4 | Text Editor |
| Alt+F5 | Settings |
| Alt+F6 | System Monitor |
| Alt+F7 | Network Manager |
| Alt+F8 | Package Center |
| Alt+F9 | About |
| Alt+Tab | Switch windows |
| Right-click | Desktop menu |

## System Commands

```bash
# System information
aira info           # OS/kernel/arch
aira version        # Version
aira system         # Kernel+CPU+memory+disk
aira platform       # Hardware details
aira status         # Services + mounts

# Service management
aira services status
aira services start|stop|restart <name>
aira services enable|disable <name>
aira services logs <name> [lines]
aira services diag <name>

# Network
aira network        # Interfaces, routes, DNS
aira network dhcp eth0

# Storage
aira storage        # Disks, mounts, persistence

# Users
aira users          # Users/groups
aira user adduser <name>
aira user passwd <name>

# Packages
aira packages list
aira packages search <term>
aira packages info <name>
aira packages install <file.apkg>
aira packages remove <name>
aira packages verify <name>
aira packages rollback <name>

# IPC
aira ipc ping
aira ipc list
aira ipc call <service> <method> [args]
aira ipc emit <topic> <message>

# Diagnostics
aira doctor         # Health check
aira diagnose       # Full dump
aira demo           # Guided tour

# Recovery
aira-recovery check all
aira-recovery fix all

# Updates
aira-update check
aira-update status
aira-update install

# Power
aira-power shutdown --force
aira-power reboot --force
aira-power suspend
aira-power status

# Audio
aira-audio volume [0-100]
aira-audio mute|unmute
aira-audio list
aira-audio test
```

## Building from Source

```bash
# Prerequisites: gcc, make, bc, flex, bison, libssl-dev, libelf-dev, cpio, grub, qemu

# Build kernel
scripts/build-kernel.sh

# Build initramfs
scripts/build-initramfs.sh

# Build persistent rootfs (optional)
scripts/build-rootfs.sh 512

# Run tests
scripts/test-all.sh

# Create release
scripts/build-release.sh 1.5.0
```

## Project Structure

```
├── configs/              # Kernel config
├── docs/                 # Documentation
├── gui/                  # Desktop applications
├── initramfs/            # Initramfs source
│   ├── init              # PID 1
│   ├── sbin/             # System services
│   ├── usr/bin/          # User commands
│   └── etc/              # Configuration
├── linux-7.2.2/          # Kernel source
├── scripts/              # Build/test scripts
└── release/              # Release artifacts
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - System design and internals
- [Security](docs/SECURITY.md) - Security model and hardening
- [Testing](docs/TESTING.md) - Test procedures
- [Building](docs/BUILDING.md) - Build instructions
- [Release Notes](RELEASE_NOTES.md) - Version history

## License

MIT License - see LICENSE file

## Version

Current: 1.5.0