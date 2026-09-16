# Live Demo Script (5–10 min, all real)

1. **Boot ISO** (`scripts/demo.sh --iso`): point out grub → Linux version → `AiraOS userspace ready`.
2. **Session**: `aira demo` — narrate identity/kernel/CPU/mem/storage/net/services/packages as they print.
3. **Terminal**: `mc`? No — open desktop Terminal (or `xterm`): run `aira system`, `ps`, `free`.
4. **System monitor**: launch, show live CPU/mem/proc; note 2s refresh.
5. **File manager**: browse /home/aira, create `demo.txt` (via Text Editor: write, save, reopen to prove).
6. **Persistence**: `echo demo > /persist/demo.txt`; reboot with same drive; `cat /persist/demo.txt`.
7. **Settings**: change hostname (`aira-settings`), show `hostname` updated.
8. **Networking**: `aira network`, `ping -c2 10.0.2.2` (user-net) or loopback.
9. **Packages**: `airapkg list/search`, install demo .apkg, verify, remove.
10. **Services**: `aira services status`, `restart net`, show log tail.
11. **Desktop**: right-click menu categories, clock + xload, close an app (desktop lives on).
12. **Shutdown**: `aira shutdown --force` (or reboot to prove repeatability).

Fallbacks: no disk → say persistence NOT AVAILABLE (system says so itself); no net →
loopback only; GUI fails → serial shell recovery (never broken by design).
