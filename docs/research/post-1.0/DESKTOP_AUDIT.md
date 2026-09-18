# Post-1.0 Desktop Audit (evidence: gui-20260918-112858.log + sources)

Stack: kernel(no FB) → Xvfb/Xorg (Ubuntu debs) → JWM → aira-session →
menu/launcher → apps. No custom display server/WM (correct reuse).

## Per-app classification
- Terminal: REAL (xterm window mapped, shell executes; window asserted).
- File Manager: WRAPPED (xterm+mc; mc --version asserted, browsing manual).
- Text Editor: WRAPPED (xterm+vi; window mapped; edit/save manual).
- System Monitor: REAL headless part (live cpu/mem asserted); window mapped.
- Settings: WRAPPED (xterm menu; window mapped; hostname-change manual).
- Network Manager: REAL headless part (--once asserted); window mapped.
- Package Center: WRAPPED (xterm menu over airapkg; window mapped).
- Sysinfo/About: REAL (content asserted from logs).
- Clock/xload tray: REAL (visible in balance of evidence: tray mapped; xload
  fixed to named colors after usage-error finding).
- Menu/launcher: REAL (JWM Aira menu with 3 categories; apps launch as separate
  PIDs; desktop survives kills — asserted).
- Notifications: ABSENT (no notification daemon; not claimed anywhere).

## Findings
- Titles lag under TCG (windows mapped unnamed first) → test uses count-based
  matching with title INFO. Honest handling, documented in test-system audit.
- xterm locale/input-method warnings: cosmetic, non-fatal (asserted harmless by
  successful window+shell use).
- Foreground Xvfb :98 trial always fails (xkbcomp path) yet :99 session works
  (session creates the symlink). Trial is diagnostic noise, not product behavior.
- Keyboard/mouse: XTEST-only evidence; no physical input events. Next: evdev
  event capture test under --gpu virtio.
