# Live Demo Script 1.0 (5–15 min, all real)

1. **Boot ISO** (`scripts/demo.sh --iso`): grub → Linux version → `AiraOS userspace ready`.
2. **Session**: `aira demo` — narrate identity/kernel/CPU/mem/storage/net/services/packages.
3. **Platform**: `aira platform` — PCI/CPU/interrupts from live sysfs.
4. **Terminal**: desktop Terminal (or `xterm`): `aira system`, `ps`, `free`.
5. **System monitor**: live CPU/mem/proc, 2s refresh.
6. **File manager + Text Editor**: browse /home/aira, create `demo.txt`, save, reopen.
7. **Persistence**: `echo demo > /persist/demo.txt`; reboot same drive; `cat` it back.
8. **Settings**: change hostname, show updated `hostname`.
9. **Networking**: `aira network`, Network Manager app, loopback ping (user-net if attached).
10. **Packages**: search/install/verify/rollback/remove a demo .apkg; Package Center UI.
11. **Services**: status, `restart net`, crash→failed→recover narrative, ordered shutdown.
12. **Desktop**: menu categories, clock + CPU load, close app (desktop survives).
13. **Dev**: install hello-aira sample from repo, run it, remove it.
14. **Shutdown**: `aira shutdown --force` (services stop in order, ACPI S5).

Fallbacks: no disk → persistence NOT AVAILABLE (system reports it); no net →
loopback only; GUI fails → serial recovery shell (by design, never broken).
