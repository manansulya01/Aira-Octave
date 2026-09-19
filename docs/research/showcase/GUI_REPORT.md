# GUI Report — AiraOS-Octave 1.1.0

Stack: Xvfb (fallback) / Xorg when /dev/dri present, JWM + xterm + mc +
x11-utils, Ubuntu debs staged by `scripts/build-gui.sh` into `rootfs/`
(`aira-rootfs.img`, mounted at /persist). No heavyweight DE.

## Desktop identity
- Aira blue (`#1d2a6b`) wallpaper, Aira tray button, task list, dock,
  live NET/DSK tray indicators (swallowed xterms, 5s/10s refresh),
  xload + clock.
- Launcher menus: System (Terminal, Monitor, Info, diagnose, About),
  Files, Development (Text Editor), Internet (Network Manager),
  Utilities (Package Center), Settings, About (+ Demo). Duplicates removed.

## Applications (all real, live data — audited line-by-line)
1. Terminal — real xterm shell. 2. File Manager — mc on the real fs
   (browse/create/open/delete; permission errors are real DAC errors).
3. Settings — real hostname change, real DHCP renew, real sysinfo
   (no fake toggles; fixed `read -p` bashism + DHCP `-s` script).
4. System Monitor — live /proc (cpu, load, mem, uptime, ps), 2s refresh.
5. System Information — live os-release/uname/cpuinfo/mem/df/ip.
6. Package Center — real airapkg (list/search/info/install/remove/update-check).
7. Text Editor — real vi on real files. 8. Network Manager — real
   link/addr/route/DNS + DHCP renew (fixed missing `-s` script).
9. About — live version/arch/kernel + project links.

## Window management (in-guest `aira-gui-test`, Xvfb :99)
- 6 client windows mapped (terminal, editor, pkgcenter, dialogs); named
  windows + xterm/xmessage clients present; sysinfo/about content checks pass.
- Kill-apps path: harness kills all app PIDs → jwm alive (`desktop survives`).
- Screenshot: `xwd -root` 3148907 bytes → `/persist/screenshots/`,
  extracted to `docs/research/showcase/evidence/desktop-1.1.0.xwd`. VERIFIED.

## Status
- Desktop boot (manual `aira-session --headless` and auto `aira_gui=1`):
  VERIFIED. Launcher/apps/windows/recovery: VERIFIED via gui-test.
- Keyboard-interactive click-through (human JWM use) and virtio-GPU/DRI
  path: PARTIAL/UNTESTED (headless TCG environment; no input automation).
