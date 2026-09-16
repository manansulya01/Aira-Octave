# AiraOS-Octave GUI (X11 + JWM, no compilation)
- X server: Xvfb (headless, always works) + Xorg modesetting (virtio-gpu, when --gpu virtio)
- WM: JWM (real window management: focus, move, close, taskbar, pager)
- Panel/clock/launcher: JWM tray + root menu (Aira branding via /etc/jwm/aira-jwmrc)
- Terminal: xterm (real shell)
- File Manager: mc in xterm (real browse/copy/move/delete) + wrapper aira-file-manager
- Settings: aira-settings (xterm menu: hostname, network, display)
- System Information: aira-sysinfo (xmessage + text dump, real uname/free/df/ip)
- About: aira-about (xmessage, real version)
- Wallpaper: xsetroot solid Aira blue
- Session: /usr/bin/aira-session (starts X, JWM, panel, first-run apps)
- Headless test: /usr/bin/aira-gui-test (Xvfb + jwm + apps + xwininfo + xwd screenshot)
All actions real. No placeholders. Falls back to text shell if X fails.
