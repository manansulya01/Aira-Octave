# AiraOS-Octave GUI (X11 + JWM, no compilation)
- X server: Xorg modesetting (VISIBLE desktop on virtio-gpu, auto-selected
  when /dev/dri/card* exists) with vesa/fbdev fallback for std VGA, +
  Xvfb (headless fallback for automated tests). See `aira-session --help`
  flags: `--auto` (default), `--xorg`, `--xvfb`, `--headless`.
- Visible boot: `bash scripts/boot-gui.sh` (QEMU `-vga virtio` + GTK window,
  serial recovery shell stays on stdio). `-vga std` (Bochs VBE) has no
  driver in this kernel/X stack, so it cannot show the desktop.
- WM: JWM (real window management: focus, move, close, taskbar, pager)
- Shell: top system panel (menu, launcher, workspaces pager, indicators,
  quick settings, clock) + bottom dock (app launchers, window task list)
  via /etc/jwm/aira-jwmrc; 1.5.0 single-tray layout kept as
  /etc/jwm/aira-jwmrc.classic and used as supervised fallback by aira-session
- Launcher: aira-launcher (search over the real app registry, --list/--find/--text)
- Quick settings: aira-quicksettings (volume/network/display/theme/session
  status + real actions on aira-audio, udhcpc, aira-theme, aira-session-mgr)
- Theme engine: aira-theme (4 original Aira themes in /etc/aira/theme.conf)
- Wallpaper: aira-wallpaper presets applied from theme.conf at session start
- Terminal: xterm (real shell)
- File Manager: mc in xterm (real browse/copy/move/delete) + wrapper aira-file-manager
- Settings: aira-settings (xterm menu: hostname, network, display)
- System Information: aira-sysinfo (xmessage + text dump, real uname/free/df/ip)
- About: aira-about (xmessage, real version)
- Wallpaper: xsetroot solid Aira blue
- Session: /usr/bin/aira-session (starts X, JWM, panel, first-run apps)
- Visible boot: `bash scripts/boot-gui.sh` (GTK window, virtio-gpu/Xorg/JWM);
  `bash scripts/boot-gui.sh --demo` opens a tiled app showroom on boot.
- Headless test: /usr/bin/aira-gui-test (Xvfb + jwm + apps + xwininfo + xwd screenshot)
All actions real. No placeholders. Falls back to text shell if X fails.
