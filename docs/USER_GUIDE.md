# AiraOS-Octave User Guide

## Shell
Boot reaches `~ #` (root). Try: `aira info`, `aira system`, `aira diagnose`, `aira network`, `airapkg list`.

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

## Diagnostic support bundle

Run `aira-support-bundle` to create a compressed diagnostic archive. By default it writes to `/persist` when that filesystem is mounted, otherwise to `/tmp`. You can supply an explicit output path ending in `.tar.gz`:

```sh
aira-support-bundle /persist/aira-support-bundle.tar.gz
```

The archive includes OS/kernel, resource, storage, network, doctor, and selected boot/service-log information. It intentionally excludes account databases, IPC tokens, package credentials, network profiles, and the raw kernel command line. It still contains local IP/routes/DNS details and system logs: inspect it before sharing, and do not upload it automatically.
