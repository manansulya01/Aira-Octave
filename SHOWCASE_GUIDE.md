# SHOWCASE GUIDE — AiraOS-Octave 1.2.0 (3–5 minute demo)

Every step below is real (no fakes). Serial console stays visible for narration.

## One command to launch the demo

Text + guided tour (fastest, no disk needed):

```sh
bash scripts/demo.sh
```

Desktop + tour (needs the GUI disk image):

```sh
bash scripts/demo.sh --gui
```

Release ISO (exact shipped artifact):

```sh
bash scripts/demo.sh --iso
```

## 3–5 minute sequence

1. **Boot (0:00–0:30).** Watch SeaBIOS/grub → `Linux version 7.2.2` →
   `AiraOS userspace ready`. Point out: kernel, initramfs, services start.
2. **System truth (0:30–1:15).** Run `aira info`, `aira system`, `aira status`.
   Note `status` says `via IPC bus` — services reported through the bus.
3. **IPC bus (1:15–2:00).** Run `aira ipc ping hello`, `aira ipc list`,
   `aira doctor`. Doctor prints PASS per area (kernel, services, IPC,
   storage, network, users). All probes are live.
4. **Desktop (2:00–3:30).** In GUI mode run `aira-session`, open the Aira
   menu: System Information (shows `[via Aira IPC bus]`), File Manager,
   System Monitor, Network Manager, Package Center, Text Editor, Terminal.
   Open a file, check DHCP, list packages — all real backends.
5. **Packages + close (3:30–5:00).** `airapkg search hello`, install the
   sample, run it, remove it. Then `aira demo` for the guided tour and
   `aira shutdown --force` to power off cleanly.

## What the audience sees

- An OS that boots, identifies itself, and reports live system truth.
- A desktop with Aira branding, menu, tray, and working apps.
- A service bus (`aira-ipc`) that CLI, doctor, and GUI actually use.
- No terminal wizardry required: menu → app → real result.

## Validation behind the demo

```sh
bash scripts/test-all.sh            # 8 suites (kernel/userspace/services/storage/network/gui/demo/iso)
bash scripts/test-release.sh 1.2.0  # build + checksums + boot exact ISO
```

Evidence: `logs/final-completion/` (per-suite logs) + GUI screenshot in
`docs/research/showcase/evidence/` + `docs/research/final/`.
