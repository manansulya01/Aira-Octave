# Wave B-2 Architecture Report (2026-09-30)

Short dependency report per mission FIRST-step. No code changed to produce this.

## Where the Wave-B shell connects (verified by reading source)

1. JWM: `gui/aira-jwmrc` is the ONLY window-manager input. Staged by
   `scripts/build-gui.sh` to `rootfs/etc/jwm/{aira-jwmrc,system.jwmrc}` +
   `aira-jwmrc.classic`, packed into `aira-rootfs.img`, mounted at
   `/persist`. `aira-session` runs `jwm -f <first-found>` with a 1s
   supervisor that falls back to `aira-jwmrc.classic`. All panel/dock/
   menu/keys/pager/desktops are JWM-native XML — no daemon, no compositor.
2. Xorg/Xvfb: `aira-session --auto` picks Xorg when `/dev/dri/card*` or
   `/dev/fb0` exists, else Xvfb. Consumers of X: `xsetroot` (wallpaper),
   `xrandr` (display row), `xmessage` (notifyd popups, about/sysinfo),
   `xwininfo/xwd/xlsclients` (tests). Available X utils in rootfs:
   Xorg, Xvfb, jwm, xlsclients, xmessage, xrandr, xsetroot, xterm,
   xwininfo, xwd (+xprop via x11-utils — to be confirmed in guest).
3. initramfs: Wave B does NOT touch it. `/init` autostarts
   `/persist/usr/bin/aira-session` on `aira_gui=1`; guest harnesses
   (`guest-autotest.sh`, in initramfs source) call `/persist/.../aira-gui-test`.
   Consequence: new guest coverage goes in `gui/aira-gui-test` (no
   initramfs rebuild needed); changing `guest-autotest.sh` would force one.
4. Persistence: `/persist` = ext4 `aira-rootfs.img` (`/dev/vda`). Theme state
   already resolves to `/persist/etc/aira/theme.conf` when present. New
   mutable state (launcher recents, notify history reference, reboot
   EXPECT marker) MUST live under `/persist` (or be copied there) to
   survive reboot; `/tmp` and `/run` are tmpfs. Host-side proof of
   persistence without a second boot: `debugfs -R "cat <path>" img`.
5. IPC/services: `aira-ipcd` on 127.0.0.1:41234 (AIRA1). Shell tools use it
   indirectly by delegating to real CLIs (`aira-audio`, `aira-power`,
   `aira-theme`, `aira-session-mgr`, `udhcpc`) — no duplicated logic, no
   fake IPC wrappers. Logout/restart/shutdown/reboot ONLY via
   `aira-session-mgr` → (`kill jwm` | `aira-init shutdown` + poweroff/reboot).

## Honest hardware boundaries (do NOT fake)

- QEMU test guest has: virtio-net (no Wi-Fi), no backlight, no battery,
  no ALSA Master mixer, software rendering. Rows for Wi-Fi/brightness/
  battery/volume MUST report "unavailable on this hardware" and tests MUST
  assert that message — an "unavailable" path is a feature, not a gap.
- JWM is NOT a compositor: no true translucency (opacity hints only),
  no animations, no thumbnail task previews. These go to the future
  compositor architecture, explicitly listed as out of scope.

## Wave B-2 connection-point changes (planned, additive)

- `aira-launcher`: registry gains `category` field; recents in
  `$AIRA_STATE_DIR` (default `/persist/var/lib/aira`, fallback
  `/var/lib/aira`); `--categories/--category/--recent/--check/--launch`.
- `aira-quicksettings`: rows read `aira-power status`, `/sys/class/
  power_supply`, `/sys/class/backlight`, `iw` presence; night mode maps to
  `aira-theme use aira-night|aira-day` + `AIRA_NIGHT` key; reboot via
  session-mgr (already exists as mechanism, newly surfaced).
- `aira-notifyd`: FIFO queue + `/var/log/airaos/notifications.log` history;
  no-DISPLAY fallback to `logger`; `aira-notify --history/--clear`.
- New indicators `aira-vol-indicator`, `aira-power-indicator` (tray
  swallows, same pattern as net/storage indicators).
- `aira-jwmrc`: workspace keys (`desktop#`/`send#`), minimize/maximize keys
  (no duplicates — enforced by test), two new indicator swallows. Classic
  untouched (test pins it to v1.5.0 SHA).
- Themes 4→6, wallpapers 4→6; `aira-theme export` feeds xterm wrappers
  (terminal/launcher/quicksettings) so styling is single-sourced.
- Evidence: `gui/aira-gui-test` gains jwmrc `jwm -p` parse, EWMH desktop
  count via `xprop`, notify queue drain, piped launcher input, state-dir
  recents, session restart, theme set/readback + reboot EXPECT marker;
  new `scripts/test-persist.sh` double-boots one image and cross-checks
  with host `debugfs`.
