# AiraOS-Octave User Guide

## Shell
Boot reaches `~ #` (root). Try: `aira info`, `aira system`, `aira diagnose`, `aira network`, `airapkg list`. For machine-readable system details, run `/usr/bin/aira-info --json`.

## Files/persistence
- Root is initramfs (RAM). Persistent disk at /persist (if booted with -drive). Test: `echo hi > /persist/me.txt`, reboot with same image, file remains (automated in test-storage.sh).

## Services
`aira service status`, `aira service restart net`. Logs in /var/log/airaos/.

## Packages
`airapkg build <dir> out.apkg`, `airapkg install out.apkg`, `airapkg verify <name>`, `airapkg remove <name>`.

## Desktop
1. Boot with `-drive aira-rootfs.img` and 1G RAM.
2. Run `/persist/usr/bin/aira-session --headless` (or `aira-session` with display).
3. Menu (right-click / Aira button): Terminal (xterm shell), File Manager (mc), Settings (hostname/net), System Information, About.
4. Recovery: serial shell always available; `pkill Xvfb; pkill jwm` returns to text.
