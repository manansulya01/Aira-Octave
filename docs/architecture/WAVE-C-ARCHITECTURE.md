# AiraOS-Octave Wave C Architecture Document

## 1. Current Architecture

Based on the system inspection, AiraOS-Octave 1.5.0 consists of:

**Core Layers:**
- Linux Kernel 7.2.2 with custom configuration
- Initramfs userspace (BusyBox-based) with PID 1 `/init` script
- Persistent rootfs (optional ext4 image mounted at `/persist`)
- Graphical desktop using JWM window manager with X11 backend

**Key Subsystems:**
- **Service Manager** (`aira-init`): Lightweight supervision via pidfiles, supports daemon/oneshot services with dependencies, respawn limits, resource limits
- **IPC Bus** (AIRA1 protocol v1): Local message bus on 127.0.0.1:41234 with request/response and event capabilities
- **Package Management** (airapkg): Local .apkg format with atomic install/rollback
- **Device Discovery**: Handlers for PCI, USB, VirtIO, input, block, network devices
- **User Management**: Standard Linux accounts with shadow passwords
- **Security Hardening**: Kernel sysctls, cgroups v2, protected filesystems
- **Recovery System**: Check/fix modes for services, storage, network, IPC, packages, graphics
- **Observability**: `aira doctor`, `aira info`, `aira status`, `aira diagnose`, `aira log`

**Current IPC Services** (handlers in `/etc/aira/ipc/handlers/`):
- `bus`: Meta service for IPC bus itself (version, services, ping, emit, events)
- `device`: Device information (list, pci, usb, input, virtio, block, net, info)
- `network`: Network facts (interfaces, routes, dns)
- `services`: Service state (status, start|stop|restart, logs, diag) - privileged methods require root token
- `storage`: Storage facts (usage, mounts, persist)
- `system`: System facts (info, version, uptime, memory, cpu, kernel, hostname)
- `user`: User information (list, current, info, groups)

## 2. Current Application Architecture

Applications are currently implemented as wrappers that delegate to real CLIs rather than using IPC directly:

**GUI Applications** (in `rootfs/usr/bin/` and symlinked from `gui/`):
- `aira-session`: X backend selection + JWM launcher
- `aira-launcher`: Application launcher (search over app registry)
- `aira-quicksettings`: Status display + actions on real CLIs (volume, network, display, theme, session)
- `aira-theme`: Theme engine (6 themes, wallpaper export)
- `aira-wallpaper`: Wallpaper management
- `aira-notify`/`aira-notifyd`: Notification daemon with FIFO queue and history
- `aira-file-manager`: Wrapper around Midnight Commander (mc)
- `aira-textedit`: Wrapper around vi
- `aira-settings`: Xterm menu for hostname/network/display settings
- `aira-sysmon`: System monitor (xmessage + text dump)
- `aira-sysinfo`: System information (xmessage + text dump)
- `aira-netman`: Network manager (placeholder - currently uses real CLIs indirectly)
- `aira-pkgcenter`: Package center (placeholder - currently uses real CLIs indirectly)
- `aira-help`: Help system
- `aira-welcome`: Welcome screen
- `aira-about`: System information
- `aira-clock`: Desktop clock
- `aira-dm`: Display manager
- `aira-volume-indicator`/`aira-power-indicator`: Tray swallows
- `aira-terminal`: xterm wrapper

**Current Pattern**: Applications use indirect IPC by calling real CLI tools that may themselves use IPC internally, rather than making direct IPC calls. For example:
- `aira-quicksettings` reads status from `aira-power status`, `/sys/class/power_supply`, etc.
- Applications launch real tools like `mc`, `vi`, `xterm` directly

## 3. IPC Architecture

**AIRA1 Protocol v1**:
- Transport: Loopback TCP on 127.0.0.1:41234 (via `nc -ll -p PORT -e handler`)
- Message format: `AIRA1|<id>|<sender>|<service>|<method>|<auth>|<args>`
- Response format: `AIRA1|<id>|OK|<payload>` or `AIRA1|<id>|ERR|<code>: <message>`
- Payloads flattened to single line (newlines converted to semicolons)
- Authentication: Root token in `/run/aira-ipc/root.token` (readable only by root)
- Privileged methods: Declared in handlers via `PRIV_METHODS` variable

**Handler Contract**:
- Input: `$1=method` `$2=args-string`
- Output: stdout=payload
- Exit codes: 0=OK, 3=ERR (with error message in stdout)
- Timeout handling: Handler timeout of 10 seconds

## 4. Existing Backend Capabilities

From examining the IPC handlers, the following capabilities are available:

**System Handler** (`system`):
- Read-only: `info`, `version`, `uptime`, `memory`, `cpu`, `kernel`, `hostname`

**Storage Handler** (`storage`):
- Read-only: `usage` (df -h), `mounts` (mount), `persist` (check if /persist mounted)

**Network Handler** (`network`):
- Read-only: `interfaces` (ip addr), `routes` (ip route), `dns` (cat resolv.conf)

**Services Handler** (`services`):
- Read-only: `status` (service status)
- Privileged (requires root token): `start|stop|restart` (service control)
- Read-only: `logs <name> [lines]` (service logs)
- Read-only: `diag <name>` (service diagnostics)

**Device Handler** (`device`):
- Read-only: `list` (device summary)
- Read-only: `pci` (PCI device enumeration)
- Read-only: `usb` (USB device enumeration)
- Read-only: `input` (input device listing)
- Read-only: `virtio` (VirtIO device enumeration)
- Read-only: `block` (block devices)
- Read-only: `net` (network interfaces)
- Read-only: `info` (detailed device info)

**User Handler** (`user`):
- Read-only: `list` (system users with UID >= 1000)
- Read-only: `current` (current user info)
- Read-only: `info <name>` (detailed user info)
- Read-only: `groups <name>` (user groups)

**Bus Handler** (`bus`):
- Read-only: `version` (IPC protocol version)
- Read-only: `services` (list available IPC services)
- Read-only: `ping` (echo test)
- Privileged: `emit` (emit event to log) - system.* topics require root token
- Read-only: `events` (retrieve event history)

## 5. Missing APIs

Based on the Wave C application requirements and inspection of current handlers, the following APIs are missing or need enhancement:

**For C1 - Files Application**:
- File operations: list directory, create file/directory, rename, copy, move, delete
- File information: permissions, ownership, timestamps, size
- Filesystem information: free space, mount details
- Path safety: canonical path resolution, traversal protection
- Operation progress/cancellation (where practical)

**For C2 - Settings Application**:
- Settings persistence: save/restore settings categories
- Hardware capability detection: report unavailable/unsupported hardware
- Category-specific controls: Appearance, Display, Network, Audio, Power, Storage, Users, Security, Accessibility, System, Developer

**For C3 - Terminal Application**:
- PTY management: create/pseudo-terminal pairs
- Shell lifecycle: spawn shell, handle exit signals
- Terminal resize: handle SIGWINCH
- Environment propagation: pass environment variables
- Working directory: track and change directory
- Keyboard input: handle special keys, copy/paste
- Multiple sessions: support for multiple terminal instances (where practical)

**For C4 - System Monitor Application**:
- Real-time metrics: CPU usage %, memory usage %, load averages
- Process listing: PID, name, user, memory, CPU usage
- Storage monitoring: per-filesystem usage
- Network monitoring: interface statistics, connection counts
- Temperature monitoring: where available via sysfs
- Battery monitoring: where available via sysfs/class/power_supply

**For C5 - Network Manager Application**:
- Interface control: up/down, MTU configuration
- IP configuration: static IP, DHCP client/server control
- Routing: add/delete routes, display routing table
- DNS management: configure resolv.conf
- Connection state: connected/disconnecting/failed states
- Network diagnostics: ping, traceroute, DNS lookup

**For C6 - Software Center Application**:
- Package operations: search, install, remove, update, verify, rollback
- Package information: name, version, description, dependencies, size
- Transaction status: install/remove/update progress
- Repository management: enable/disable repositories
- Security: package verification, trusted sources

## 6. Security Boundaries

**IPC Security Model**:
- Loopback-only binding: IPC bus only accessible from localhost
- Root token authentication: Privileged methods require presenting root-readable token
- DAC-based: Authentication via file permissions, not identity claims
- Service handler validation: All handlers validate input parameters
- Privileged method gating: Handlers check for `PRIV_METHODS` and require root token
- Input sanitization: Handlers reject malformed IDs, senders, service/method names
- Length limits: Maximum line length of 8192 bytes for IPC messages

**Current Privileged Methods**:
- `services`: start, stop, restart (require root token)
- `bus`: emit on system.* topics (require root token)

**Running Contexts**:
- System services (daemon type): Run as root via setsid + direct exec
- Unprivileged services: Run via su -c to specified user
- Oneshoot services: Run once then exit, can be unprivileged
- GUI applications: Run as the user who started the session (typically UID 1000)

## 7. Performance Risks

**Identified Performance Considerations**:
- **IPC Overhead**: Each IPC call involves TCP connection setup/teardown (via nc -ll -p -e)
- **Handler Forking**: Each connection spawns a new handler process
- **Blocking Calls**: Synchronous IPC calls may block GUI thread
- **Polling Risk**: Applications may be tempted to poll for updates instead of using events
- **Process Spawning**: Many current implementations spawn real CLI tools (mc, vi, etc.)

**Mitigation Strategies for Wave C**:
- Keep IPC messages small and infrequent where possible
- Consider connection pooling for frequent IPC users (advanced optimization)
- Use asynchronous patterns where GUI responsiveness is critical
- Leverage IPC event system (`bus emit`/`bus events`) for notifications
- Evaluate whether direct filesystem access is safer/more performant than IPC for certain operations

## 8. Dependency Map

**Load-bearing Dependencies (must not break)**:
1. `/init` contract: mounts → mdev → /persist → `aira-init boot` → shell
2. Desktop requires `/persist` (`-drive aira-rootfs.img`) for graphical session
3. `aira-session` backend selection (Xorg when GPU available else Xvfb)
4. IPC bus (`aira-ipcd`, 127.0.0.1:41234, AIRA1) as API surface for new apps
5. `airapkg`: atomic staged install + rollback foundation

**Wave C Specific Dependencies**:
- Filesystem access: Safe path handling for file operations
- PTY allocation: /dev/ptmx or posix_openpt() for terminal application
- Process management: fork()/exec() for terminal shell lifecycle
- System interfaces: /proc, /sys, /dev for monitoring applications
- Package database: Direct access or IPC enhancement for software center

**Current Usage Patterns**:
- Direct filesystem access: Used by initramfs, service definitions, configs
- Real CLI delegation: Current apps use `mc`, `vi`, `xterm`, etc. directly
- Indirect IPC: Apps call CLIs that may use IPC internally (e.g., `aira-power`)
- IPC event logging: Notifications use `aira-notifyd` which logs to file

## 9. Wave C Implementation Plan

**Overall Approach**: Implement one application at a time, progressing from shared infrastructure to end-user applications.

### C0 — Shared Aira System API / IPC Client Foundation
**Goal**: Determine if a small shared IPC client layer is justified to avoid duplicating IPC connection handling across applications.

**Analysis**: 
- Current IPC handlers require manual socket connection, message framing, and response parsing
- Applications would benefit from standardized connection handling, request/response framing, authentication, timeouts, error handling
- However, adding abstraction layer increases complexity and dependencies
- Decision: Implement a minimal IPC client library if duplication exceeds justification threshold

**Implementation Steps**:
1. Survey IPC usage patterns in potential Wave C applications
2. Extract common IPC connection/handling code patterns
3. Determine if shared library reduces code duplication significantly
4. If justified, create `/usr/lib/aira-ipc.sh` or similar with functions:
   - `aira_ipc_call service method args` → synchronous request/response
   - `aira_ipc_emit topic message` → emit event
   - `aira_ipc_event_subscribe topic callback` → event subscription (if needed)
5. Handle authentication (root token retrieval), timeouts, error propagation
6. Keep library small, dependency-free, POSIX sh compatible

### C1 — FILES
**Goal**: Build a real file manager with safe filesystem operations.

**Features to Implement**:
- Directory browsing: List contents with metadata (size, permissions, timestamps)
- File browsing: Navigate directory hierarchy
- Create file/directory: Safe creation with permission handling
- Rename: Atomic rename within same filesystem
- Copy/move: Efficient copying with progress indication where practical
- Delete: Safe deletion with confirmation
- Trash: Where supported (freedesktop trash specification)
- Permissions/octet: View and modify permission modes
- Ownership: View UID/GID (modification requires privileges)
- Timestamps: Access/modification/change times
- Size: File size and disk usage
- Free space: Per-filesystem available space
- Mount information: List mounted filesystems
- Hidden files: Toggle visibility with proper handling
- Error reporting: Clear error messages for failed operations
- Safe path handling: Prevent path traversal attacks
- Operation cancellation: Where practical (long-running copies)

**Technical Approach**:
- Prefer direct filesystem APIs over shell commands for safety
- Use `find`, `stat`, `cp`, `mv`, `rm` with careful argument handling
- Implement path canonicalization and validation
- Use IPC only where it provides clear advantage (e.g., mount information via storage handler)
- Progress indication for long-running operations
- Error handling with specific error codes/messages

### C2 — SETTINGS
**Goal**: Create a proper settings architecture with persistent storage.

**Categories to Support**:
- Appearance: Themes, wallpapers, interface scaling
- Display: Resolution, refresh rate, multiple monitors
- Network: Wi-Fi, Ethernet, proxy settings
- Audio: Volume, input/output devices
- Power: Suspend/hibernate, battery behavior
- Storage: Filesystem preferences, automation
- Users: Account preferences, session behavior
- Security: Privacy settings, security features
- Accessibility: Font sizing, high contrast, screen reader
- System: Updates, logging, performance options
- Developer: Developer features, debugging options

**Implementation Approach**:
- Each control must map to real system state
- Unsupported hardware must display UNAVAILABLE/UNSUPPORTED honestly
- Settings persistence: Store in `/persist/etc/aira/settings.conf` or similar
- Backend detection: Use IPC handlers where available, direct sysfs/proc where needed
- Frontend: Settings application with category navigation
- Apply settings immediately where possible, defer others until reboot

### C3 — TERMINAL
**Goal**: Implement a stable terminal application.

**Features to Implement**:
- PTY: Create and manage pseudo-terminal pairs
- Shell lifecycle: Spawn login shell, handle termination
- Resize: Handle SIGWINCH, propagate to PTY
- Environment: Pass and update environment variables
- Working directory: Track and change via shell builtins
- Keyboard: Handle special keys (Ctrl+C, Ctrl+Z, etc.), copy/paste
- Signals: Forward signals to child process appropriately
- Exit handling: Clean termination, return exit status
- Theme: Integration with aira-theme system
- Multiple sessions: Support for tabbed or windowed multiple terminals
- Safe cleanup: Proper resource cleanup on exit
- Recovery serial console: Never interfere with recovery serial console

**Technical Approach**:
- Use `posix_openpt()`/`grantpt()`/`unlockpt()`/`ptsname()` for PTY allocation
- Fork/exec to create shell process
- Use select()/poll() for bidirectional communication
- Handle window size changes via ioctl(TIOCSWINSZ)
- Environment propagation via extern environ
- Working directory via getcwd()/chdir() builtins
- Special key handling via termios configuration

### C4 — SYSTEM MONITOR
**Goal**: Real metrics monitoring application.

**Metrics to Display**:
- CPU: Usage percentage, load averages (1,5,15 min)
- Memory: Usage percentage, total/used/free, swap usage
- Uptime: System boot time
- Processes: List with PID, name, user, CPU%, memory%
- Storage: Per-filesystem usage, total/used/free
- Network: Interface statistics (RX/TX bytes, packets, errors)
- Temperature: Available thermal zone readings
- Battery: Charge percentage, status (charging/discharging), time remaining
- Services: Running/failed status from service manager

**Implementation Approach**:
- Avoid excessive polling: Use reasonable update intervals (1-2 seconds)
- Leverage existing IPC handlers where possible:
  - Storage usage: `aira-ipc call storage usage`
  - Network interfaces: `aira-ipc call network interfaces`
  - DNS: `aira-ipc call network dns`
  - System info: `aira-ipc call system info`
  - CPU info: `aira-ipc call system cpu`
  - Uptime: `aira-ipc call system uptime`
- Enhance IPC handlers if needed for monitoring-specific data:
  - Add CPU usage percentage handler
  - Add memory usage percentage handler
  - Add per-process statistics
  - Add network interface statistics
  - Add temperature sensor enumeration
  - Add battery status reporting
- Use direct sysfs/proc access where IPC enhancement not justified
- Update display periodically with new measurements
- Provide process management (kill, renice) where appropriate

### C5 — NETWORK MANAGER
**Goal**: Backend-driven networking application.

**Features to Implement**:
- Interfaces: List available network interfaces with status
- Link state: Show if interface is connected, speed, duplex
- IPv4/IPv6: Address assignment, DNS configuration
- Routes: Display and manipulate routing table
- DNS: Configure resolv.conf, specify DNS servers
- DHCP: Client control (release/renew), server status
- Connection state: CONNECTED, CONNECTING, DISCONNECTED, FAILED
- Network diagnostics: Ping, traceroute, DNS lookup
- Explicit states: Honest reporting of UNAVAILABLE/UNSUPPORTED

**Implementation Approach**:
- Use existing network handler for basic information
- Enhance network handler for configuration capabilities:
  - Interface configuration (IP address, netmask, MTU)
  - Routing table manipulation
  - DNS configuration
  - DHCP client control
- Privileged methods will require root token authentication
- Provide user-friendly interface for network selection and configuration
- Implement state machine for connection tracking
- Network diagnostics as separate tools or integrated features
- Honest hardware reporting: Show unavailable/unsupported where appropriate

### C6 — SOFTWARE CENTER
**Goal**: Package management application using airapkg.

**Features to Implement**:
- Installed packages: List with name, version, description
- Search: Search available packages by name/description
- Information: Detailed package view (dependencies, size, etc.)
- Install: Install packages with progress indication
- Remove: Remove packages with dependency checking
- Update: Check for and apply available updates
- Transaction status: Show progress of install/remove/update
- Rollback status: Show status of rollback operations
- Errors: Clear error messages for failed operations
- Repository state: Show enabled repositories, last update time

**Implementation Approach**:
- Leverage existing airapkg CLI directly where possible
- Enhance airapkg or create IPC handler for structured data if CLI output parsing is problematic
- Current airapkg supports: list, search, info, install, remove, verify, rollback
- Consider adding IPC handler for structured JSON-like output if needed for GUI
- Use atomic transactions and rollback safety of airapkg
- Provide clear feedback on long-running operations
- Handle repository refresh and update checking
- Display security information when available (signatures, trusted sources)

### C7 — DIAGNOSTICS
**Goal**: Unified diagnostics application.

**Features to Implement**:
- Kernel: Version, boot parameters, loaded modules
- Aira version: OS version, build information
- Boot state: Boot time, initramfs persistence, service startup
- Services: Status of all enabled services
- IPC: Bus status, event history, connected clients
- Storage: Usage, filesystem health, SMART data where available
- Network: Interface status, connectivity tests
- Devices: Enumeration of PCI/USB/VirtIO/input devices
- Packages: Installed packages, update availability, integrity
- Security: Hardening status, vulnerability information
- Logs: System and service log viewing
- Recovery: Last recovery actions, known good states
- Hardware capabilities: CPU features, virtualization support

**Implementation Approach**:
- Aggregate data from existing sources:
  - Kernel: `uname -a`, `/proc/version`, `/proc/cmdline`, `/proc/modules`
  - Aira version: `/etc/os-release`, `aira version`
  - Boot state: Boot logs, service startup times
  - Services: `aira-init status` or IPC equivalent
  - IPC: `aira-ipc call bus services`, `aira-ipc call bus events`
  - Storage: `aira-ipc call storage usage/mounts`, direct SMART where available
  - Network: `aira-ipc call network interfaces/routes/dns`, ping tests
  - Devices: `aira-ipc call device list/pci/usb/input/virtio/block/net`
  - Packages: `aira pkg list/info`, integrity checks
  - Security: Audit of hardening settings, cgroup usage
  - Logs: Direct log file viewing or `aira log`
  - Recovery: Recovery logs, last known good state markers
  - Hardware: `lscpu`, `/sys/devices/virtual/dmi/id`, virtualization flags
- Present information in organized, tabbed interface
- Provide actionable items where problems detected
- Export diagnostic bundles for off-site analysis

### C8 — WELCOME/ABOUT/HELP
**Goal**: Integrated help system.

**Components to Integrate**:
- About: System information (already exists as aira-about)
- Welcome: First-boot experience, setup guidance
- Help: Contextual help, documentation access
- Documentation: Local copies of key documentation files
- Diagnostics: Launch diagnostics application
- Recovery guidance: Boot recovery options, troubleshooting steps

**Implementation Approach**:
- Reuse existing `aira-about` for system information
- Create welcome system that detects first-boot state
- Help system that provides contextual assistance
- Link to documentation files in `/usr/share/doc/aira-octave/` or similar
- Integrate diagnostics application launch
- Provide recovery guidance based on common failure modes
- Avoid duplicating documentation - link to existing files where possible

## 10. Long-term Production Architecture

Beyond Wave C, the system should evolve toward:

**Modular IPC Services**:
- Fine-grained service separation (e.g., split storage into filesystem, block, mount)
- Standardized service interfaces with versioning
- Async communication patterns where appropriate
- Service discovery and dynamic loading

**Enhanced Security Framework**:
- Mandatory Access Control (MAC) integration where justified
- Application sandboxing via namespaces/cgroups
- Secure boot and measured boot capabilities
- Enhanced auditing and anomaly detection

**Advanced Service Management**:
- Dependency-based startup with parallelization
- Service templates and instantiation
- Health checks and automatic restart policies
- Resource quota management per service

**Unified Configuration System**:
- Hierarchical configuration (system/defaults, machine, user, application)
- Configuration change notification
- Rollback and validation of configuration changes
- Schema-based configuration with types and constraints

**Improved Device Management**:
- Hot-plug support with automatic configuration
- Driver abstraction layers where Linux doesn't provide
- Power management integration
- Device policies and access controls

**Enhanced Observability**:
- Structured logging with levels and facilities
- Distributed tracing for IPC calls
- Real-time metrics export (Prometheus-compatible)
- Health check endpoints and readiness probes
- Performance profiling and bottleneck identification

## 11. Known Technical Debt

**From Inspection**:

1. **IPC Inefficiency**: Each IPC call creates new TCP connection and handler process
   - Impact: Latency for frequent IPC users
   - Mitigation: Consider connection pooling or Unix domain sockets for high-frequency use

2. **Indirect IPC Usage**: Current applications delegate to real CLIs rather than using IPC directly
   - Impact: Duplicated logic, inconsistent error handling
   - Mitigation: Wave C aims to convert wrappers to IPC-backed tools

3. **Settings Persistence**: No unified settings system identified
   - Impact: Settings may be lost or inconsistent
   - Mitigation: Wave C2 will implement proper settings architecture

4. **Hardware Detection Honesty**: Some rows may fake capabilities rather than reporting unavailable
   - Impact: Misleading user experience
   - Mitigation: Wave C applications must report honest hardware boundaries

5. **Error Handling Consistency**: Variable error reporting across applications
   - Impact: Poor user experience when things fail
   - Mitigation: Standardize error reporting patterns in Wave C

6. **Resource Leak Potential**: Long-running applications may leak file descriptors or memory
   - Impact: Degraded performance over time
   - Mitigation: Proper resource cleanup in all Wave C applications

7. **Testing Coverage**: GUI applications tested primarily via headless/Xvfb
   - Impact: Limited validation of graphical behavior
   - Mitigation: Continue requiring both headless/Xvfb and graphical QEMU testing

## 12. Recommended Execution Order

Based on dependencies and logical progression:

1. **C0 - Shared IPC Client Foundation** (Optional, based on duplication analysis)
   - Analyze IPC usage in target applications
   - Implement if justification threshold met

2. **C1 - FILES**
   - Foundation for file operations used by other applications
   - Relatively self-contained
   - Provides basic file management functionality

3. **C2 - SETTINGS**
   - Infrastructure for persistent configuration
   - Used by nearly all other applications
   - Enables personalization and system configuration

4. **C3 - TERMINAL**
   - Core user interface for command-line interaction
   - Dependencies: PTY handling, process management
   - Enables access to system for users preferring CLI

5. **C4 - SYSTEM MONITOR**
   - Provides system health visibility
   - Dependencies: IPC enhancements for monitoring data
   - Useful for debugging and optimization

6. **C5 - NETWORK MANAGER**
   - Enables network configuration and diagnostics
   - Dependencies: IPC enhancements for network control
   - Critical for system connectivity

7. **C6 - SOFTWARE CENTER**
   - Package management interface
   - Dependencies: airapkg CLI or IPC enhancements
   - Enables system extensibility and updates

8. **C7 - DIAGNOSTICS**
   - Unified troubleshooting and system insight
   - Dependencies: Aggregation from multiple sources
   - Critical for maintenance and support

8. **C8 - WELCOME/ABOUT/HELP**
   - User onboarding and assistance
   - Dependencies: Minimal, mostly integration
   - Completes user experience package

**Validation Criteria for Each Application**:
- Source implemented and builds without errors
- Static analysis passes (sh -n for shell tools)
- Runtime tests pass in headless/Xvfb environment
- Guest testing passes in graphical QEMU environment
- Failure paths tested (invalid input, missing hardware, etc.)
- Regression testing passes (existing functionality unaffected)
- Documentation updated with usage and limitations
- Performance measured and acceptable
- Security boundaries honored (no privilege escalation)
- Honest hardware reporting where applicable

This architecture document provides the foundation for Wave C implementation while maintaining compatibility with the existing AiraOS-Octave 1.5.0 system and following the established design principles of lightweight, optimized, secure, reliable, maintainable, modular, fast, observable, recoverable, user-friendly, and developer-friendly systems.

## 13. C0 Audit Record — 2026-10-03 (HEAD 5d3f81430)

**Scope verified:** IPC bus (aira-ipcd + aira-ipc-handle + 7 handlers), CLI
(`initramfs/usr/bin/aira-ipc`), shared lib (`usr/lib/aira-ipc.sh`),
consumers (`gui/aira-settings`, `gui/aira-sysinfo`,
`usr/share/doc/aira-octave/examples/ipc-client-example.sh`),
builds (`scripts/build-initramfs.sh`, `scripts/build-gui.sh`),
tests (`scripts/test-shell.sh` 107 checks).

**Bugs found and fixed in this pass:**
1. `gui/aira-settings` broken `printf` (missing closing quote/newline) —
   `sh -n` still passed but runtime box drawing was corrupt. Fixed.
2. `usr/lib/aira-ipc.sh` timeout-arg bug: `aira_ipc_emit`,
   `aira_ipc_list_services`, `aira_ipc_ping` passed 5 args to the 4-arg
   `_aira_ipc_raw_call`, so timeout was `""` instead of `$AIRA_IPC_TIMEOUT`.
   Fixed to 4-arg calls.
3. `gui/aira-sysinfo` misused lib as a pipe source
   (`aira_ipc_call … | tr`), but lib returns payload in
   `$_AIRA_IPC_RESPONSE` (stdout empty). Fixed to `printf "%s\n" "$var"`.
   Same file now reports `$_AIRA_IPC_ERROR` on failure instead of silence.
4. Unconditional `. /usr/lib/aira-ipc.sh` would abort apps when the lib is
   absent from the image. Both consumers now guard with
   `[ -f /usr/lib/aira-ipc.sh ]` plus stub fallbacks (direct /proc reads).
5. Request-id used `$$ + epoch-seconds` only — collision-prone under
   concurrent IPC clients. Now `pid-epoch-RANDOM`, truncated to the 32-char
   bus limit. Added `_aira_ipc_valid_name` so service/method reject `|`,
   newlines, uppercase-leading names before hitting the wire.
6. Edit tooling stripped `+x` from `gui/aira-settings`/`gui/aira-sysinfo`,
   breaking `test-shell.sh` ("missing exec targets"). Restored `chmod +x`;
   `test-shell.sh` back to 107/107 PASS.

**Integration (the actual C0 deliverable):**
- Canonical source: `usr/lib/aira-ipc.sh` (+ `+has_service`/`+print` helpers).
- `initramfs/usr/lib/aira-ipc.sh` is now a tracked copy (guest `/usr/lib`).
- `scripts/build-initramfs.sh` syncs canonical → initramfs source and fails
  if canonical is missing; `scripts/build-gui.sh` stages the lib into
  `rootfs/usr/lib/aira-ipc.sh` (mode 644).
- New helpers: `aira_ipc_has_service <svc>` (capability discovery),
  `aira_ipc_print` (stdout emitter for command substitution).

**Not yet done (correctly deferred):** per-method capability discovery
(bus has no `method-help` verb yet), async/event-subscribe API, Unix-socket
transport, connection pooling. Documented as future work; no fake API added.

**Evidence:** `sh -n` on lib + both consumers PASS;
`scripts/test-shell.sh` 107/107 PASS (2026-10-03);
`git diff` for this milestone touches only C0 files listed below.

**C0 guest close-out (2026-10-04):** rebuilt initramfs from source and booted
QEMU `aira_autotest=1` → `===== GUEST AUTOTEST PASS =====`, 128 OK / 0 FAIL
(log `logs/final-completion/c0-autotest.log`, preserved on disk, untracked).
Covers ping/list/all service calls, priv-denial ×2, malformed/version/id/
service/method violations, oversize, post-abuse ping, 10× repeat, 5×
concurrent, event cap, handler-timeout, crash/recovery, daemon kill/restart.
C0 status: IMPLEMENTED + TESTED + VERIFIED.

## 14. C1 Record — 2026-10-04 (IPC-backed Files)

**Deliverables:**
- `initramfs/etc/aira/ipc/handlers/files` (service `files`): `caps|list|stat`
  open; `mkdir|rename|copy|move|delete` PRIVILEGED (root token, same precedent
  as `services` start/stop). Args are `|`-separated (spaces OK; `|`/newline
  rejected). No `eval`; fixed argv only (`cp/mv/mkdir/rm/rmdir/stat` + `--`).
- Path policy: absolute-only; `..`/encoded (`%00 %2e %2f %5c`)/pipe/newline
  rejected; `//`+`/./` collapsed; symlink targets resolved and re-checked;
  reads deny `root.token`+`shadow`/`gshadow`; writes confined to
  `/root /home /tmp /persist /var/lib/airapkg/repo`; symlink sources refused
  for copy; destinations never clobbered; non-empty dirs never deleted;
  partial copies cleaned; cross-fs move = copy+unlink with rollback.
- `initramfs/usr/bin/aira-files`: bus-first CLI, local-handler fallback with
  identical semantics (fallback proven by host suite with no bus present).
- `gui/aira-file-manager`: new `--once <dir>` (testable listing) and `--text`
  (IPC browser: list/stat/mkdir/rename/copy/move/delete, hidden toggle);
  graphical `mc` backend unchanged and still present in drive image.
- `initramfs/sbin/guest-fileops.sh`: +26 IPC checks (ops + non-empty refusal
  + 4 attack rejections + bus-traversal + unprivileged-write denial).
- `scripts/test-files.sh`: 56 host checks (handler direct + CLI fallback +
  attacks + spaced names + manager `--once`).

**Evidence:** host `test-files.sh` 56/56; `test-shell.sh` 107/107;
`test-features.sh` 52/52; guest `aira_fileops=1` WITH drive →
`===== FILEOPS PASS =====` (26/26 incl. mc backend; log
`logs/final-completion/c1-fileops-drive.log`). Diskless boot shows the
pre-existing `mc missing` INFO/FAIL (mc ships in rootfs image, not initramfs)
— mode-dependent, not a C1 defect. C1 status: IMPLEMENTED + TESTED +
VERIFIED (host + guest, bus + local paths).

**Deferred honestly:** recursive copy/tree delete over IPC (explicit per-file
ops only — safer default); trash/recycle spec; progress/cancel streaming
(single-request/response bus has no streaming verb); `files` write access for
non-root desktop users (requires D3 session/ownership work first).

## 15. C2 Record — 2026-10-04 (Centralized Settings)

**Deliverables:**
- `initramfs/etc/aira/settings-schema` (v1, 12 keys, 6 namespaces): typed
  (enum/int/bool/string), constraints, `always|wifi|backlight|mixer` caps.
- `initramfs/etc/aira/ipc/handlers/settings`: `caps|get|list|validate` open;
  `set|reset` PRIVILEGED. Validate → capability-gate (UNAVAILABLE honesty) →
  apply → atomic store. Unknown store lines preserved (validate reports);
  `reset all` rebuilds factory state (purges corruption).
- `initramfs/usr/bin/aira-cfg`: bus-first CLI, identical local fallback.
- `gui/aira-settings`: MANAGED SETTINGS section (live store + UNAVAILABLE
  rows); hostname/theme/night/opacity actions routed through the store.
- `initramfs/sbin/guest-settingstest.sh` + `/init` `aira_settingstest=1`
  stanza: 23 guest checks.
- `scripts/test-settings.sh`: 55 host checks (validation, corruption,
  unwritable-store, concurrency atomicity, CLI fallback, UI smoke).

**Bugs caught by tests (fixed):** GNU-ERE `\|` alternation in key lookup made
every key resolve to the first schema line (wrong specs, unknown keys
accepted) — replaced with exact `awk -F'|'` match + `_s_ns_keys` helper.
`reset all` left corrupt lines behind — now rebuilds factory store.

**Evidence:** host 55/55; shell 107/107; features 52/52; guest with drive →
`===== SETTINGS TEST PASS =====` (23/23: bus path, /persist durability,
live hostname apply, corruption, concurrency last-writer-wins,
unprivileged denial; log `c2-settings.log`).

**Deferred honestly:** double-boot persistence proof (store prefers /persist
when mounted — verified; reboot round-trip still open); per-key change
events; non-root writer roles (needs D3).

## 16. C3 Record — 2026-10-04 (Terminal Sessions)

**Architecture (honest split):** kernel owns PTYs, xterm owns window/PTY/
resize/signals/scrollback/clipboard; Aira owns SESSION lifecycle the desktop
lacked (fire-and-forget xterms): tracked spawn, ownership, limits, cleanup.

**Deliverables:**
- `initramfs/etc/aira/ipc/handlers/terms`: `caps|list` open;
  `spawn|kill|cleanup` PRIVILEGED. Validated
  shell (basename allowlist + executable) and cwd; per-session VSZ cap 1G;
  one file per session (no shared rewrite races); max 32; self-kill by uid,
  others only via root token (self-claimed uid 0 grants nothing);
  TERM-only signaling (no SIGKILL escalation); xterm stderr captured to
  session `.err` (kept on failure, orphan-pruned by cleanup).
- `initramfs/usr/bin/aira-term`: bus-first CLI, identical local fallback.
- `gui/aira-terminal`: `--list/--kill/--cleanup/--once`; default launch via
  tracked spawn with direct-xterm fallback; CWD no longer interpolated.
- `initramfs/sbin/guest-termtest.sh` + `/init` `aira_termtest=1`: 24 checks
  incl. kernel-ptmx proof, PTY-master proof, concurrency, privilege denial.
- `scripts/test-terms.sh`: 37 host checks.

**Bugs caught by testing (fixed):** 512M VSZ cap killed xterm at startup
(Xft/mesa mmap) → 1G + `.err` capture; hand-rolled `Xvfb :99` died on the
missing `/usr/bin/xkbcomp` compat symlink — test now uses the PRODUCTION
`aira-session --headless` path (which owns X bring-up) instead of
duplicating it; claimed-uid-0 trust hole closed (token-only privilege).

**Evidence:** host 37/37; shell 107/107; guest with drive →
`===== TERMTEST PASS =====` (24/24 incl. real spawn, PTY master held,
3 concurrent, kill+reap; log `c3-termtest7.log`).

**Deferred honestly:** SIGKILL escalation path (operator uses kill(1));
per-session CPU/mem accounting; scrollback persistence; remote/headless
PTY allocation (no screen/tmux class daemon — xterm only).

## 17. C4 Record — 2026-10-04 (Efficient Monitoring)

**Deliverables:**
- `initramfs/etc/aira/ipc/handlers/sysstat` (read-only, no privilege gate):
  `caps|snapshot`. One fork emits cpu (avg-since-boot %, model, count),
  load, uptime, mem/swap, procs count + top-8, storage (/ + /persist),
  net counters, thermal/battery (only when sysfs exposes them), services.
- `initramfs/usr/bin/aira-sysstat`: bus-first CLI + `watch [N]`.
- `gui/aira-sysmon`: `--once` via single snapshot call (legacy multi-spawn
  body kept as fallback); graphical mode uses `watch 2`.
- `initramfs/sbin/guest-monitest.sh` + `/init` `aira_monitest=1`: 23 checks
  (sections, caps-vs-reality sensor honesty, bus discipline, 3× speed,
  watch frames, sysmon-backend integration).
- `scripts/test-sysstat.sh`: 31 host checks incl. measured overhead.

**Bugs caught by testing (fixed):** handler exited 1 on healthy systems
(trailing `&&` as last command → explicit `exit 0`); BusyBox `ps -o`
unsupported in guest → plain-`ps` fallback rows; stale Oct-1 rootfs image
served pre-C4 GUI apps to guests (sysmon-backend check failed honestly) →
rebuilt rootfs via incremental build-gui + build-rootfs, then re-proved
FILEOPS + TERMTEST + MONTEST against the fresh image.

**Evidence:** host snapshot avg 123ms/144ms end-to-end (measured);
host 31/31; shell 107/107; features 52/52; guest `===== MONTEST PASS =====`
(23/23 incl. 3 snapshots in 2-3s; logs `c4-monitest3.log`).

**Deferred honestly:** instantaneous cpu% (would cost 1s sleep per call);
per-process CPU% on BusyBox (fallback rows carry `?`); monitor-overhead
accounting under load (idle-only measurement so far).