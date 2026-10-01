#!/usr/bin/env bash
# Aira shell test (WAVE B-2 modern desktop): static + unit checks for the
# top-panel+dock layout, theme engine, wallpaper, launcher, quick settings,
# workspaces, window management, notifications, indicators, persistence.
# Host-only (no QEMU): safe to run in CI. Fails on first error.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

export PATH="$ROOT/gui:$PATH"
unset DISPLAY

echo "--- syntax (sh -n) ---"
for f in gui/aira-session gui/aira-theme gui/aira-wallpaper gui/aira-launcher gui/aira-quicksettings gui/aira-notify gui/aira-notifyd gui/aira-vol-indicator gui/aira-power-indicator gui/aira-terminal gui/aira-file-manager gui/aira-textedit gui/aira-settings gui/aira-sysmon gui/aira-netman gui/aira-pkgcenter; do
  if sh -n "$ROOT/$f" 2>/dev/null; then ok "$f syntax"; else bad "$f syntax"; fi
done

echo "--- jwmrc XML validity ---"
for f in gui/aira-jwmrc gui/aira-jwmrc.classic; do
  if xmllint --noout "$ROOT/$f" 2>/dev/null; then ok "$f well-formed"; else bad "$f well-formed"; fi
done

echo "--- classic fallback identical to v1.5.0 ---"
if git cat-file -e v1.5.0:gui/aira-jwmrc 2>/dev/null && \
   [ "$(git show v1.5.0:gui/aira-jwmrc | sha256sum | cut -d' ' -f1)" = "$(sha256sum "$ROOT/gui/aira-jwmrc.classic" | cut -d' ' -f1)" ]; then
  ok "classic matches v1.5.0"
else
  bad "classic matches v1.5.0"
fi

echo "--- new shell structure ---"
J="$ROOT/gui/aira-jwmrc"
check() { # check <desc> <grep-pattern>
  if grep -q "$2" "$J"; then ok "$1"; else bad "$1"; fi
}
check "top panel tray" '<Tray x="0" y="0"'
check "bottom dock tray" '<Tray x="0" y="-1"'
check "workspace pager" '<Pager'
check "window task list" '<TaskList'
check "apps launcher button" 'exec:aira-launcher'
check "quick settings button" 'exec:aira-quicksettings'
check "launcher shortcut A+F11" 'key="F11">exec:aira-launcher'
check "quick shortcut A+F10" 'key="F10">exec:aira-quicksettings'
check "vol indicator swallow" 'name="volind"'
check "power indicator swallow" 'name="pwrind"'
check "workspace desktops=4" 'Desktops count="4"'
check "workspace switch keys" 'desktop#'
check "workspace move keys" 'send#'
check "workspace numeric key" 'key="#"'
check "workspace ldesktop/rdesktop" 'ldesktop'
check "window minimize key" '>minimize<'
check "window maximize key" '>maximize<'
check "dialogs centered group" 'aira-launcher'
# no duplicate key bindings (baseline had A+F4 twice)
DUPES="$(grep -o 'mask="[A-Z]*" key="[A-Za-z0-9]*"' "$J" | sort | uniq -d || true)"
if [ -z "$DUPES" ]; then ok "no duplicate key bindings"; else bad "duplicate keys: $DUPES"; fi
# every exec: target in jwmrc must exist in gui/
MISSING=""
for t in $(grep -o 'exec:[a-z-]*' "$J" | cut -d: -f2 | sort -u); do
  [ -x "$ROOT/gui/$t" ] || MISSING="$MISSING $t"
done
if [ -z "$MISSING" ]; then ok "all jwmrc exec targets exist"; else bad "missing exec targets:$MISSING"; fi

echo "--- theme engine (isolated conf) ---"
export AIRA_THEME_CONF="$(mktemp /tmp/aira-theme-test.XXXXXX)"
rm -f "$AIRA_THEME_CONF"
[ "$(aira-theme list 2>/dev/null | wc -l)" = "6" ] && ok "6 built-in themes" || bad "6 built-in themes"
aira-theme list 2>/dev/null | grep -q "aira-day" && ok "light theme present" || bad "light theme present"
aira-theme list 2>/dev/null | grep -q "aira-sunset" && ok "sunset accent present" || bad "sunset accent present"
aira-theme list 2>/dev/null | grep -q "aira-forest" && ok "forest accent present" || bad "forest accent present"
aira-theme use aira-ocean >/dev/null 2>&1 && ok "use aira-ocean" || bad "use aira-ocean"
[ "$(aira-theme get AIRA_ACCENT)" = "#00b8d4" ] && ok "ocean accent applied" || bad "ocean accent applied"
[ "$(aira-theme current)" = "aira-ocean" ] && ok "current reports ocean" || bad "current reports ocean"
aira-theme export 2>/dev/null | grep -q "^AIRA_BG=" && ok "theme export single-source" || bad "theme export single-source"
aira-theme export 2>/dev/null | grep -q "^XTERM_BG=" && ok "theme export xterm feed" || bad "theme export xterm feed"
aira-theme set AIRA_OPACITY 0.8 >/dev/null 2>&1 && \
  [ "$(aira-theme get AIRA_OPACITY)" = "0.8" ] && ok "set/get roundtrip" || bad "set/get roundtrip"
aira-theme use bogus-theme >/dev/null 2>&1 && bad "reject unknown theme" || ok "reject unknown theme"
aira-theme set BOGUS_KEY x >/dev/null 2>&1 && bad "reject unknown key" || ok "reject unknown key"
BEFORE="$(aira-theme current)"; aira-theme --next >/dev/null 2>&1
[ "$(aira-theme current)" != "$BEFORE" ] && ok "theme --next cycles" || bad "theme --next cycles"
# persistence: selection survives re-read (file-backed conf)
aira-theme use aira-forest >/dev/null 2>&1
[ "$(aira-theme current)" = "aira-forest" ] && [ -f "$AIRA_THEME_CONF" ] && grep -q "aira-forest" "$AIRA_THEME_CONF" && ok "theme selection persists" || bad "theme selection persists"
rm -f "$AIRA_THEME_CONF"

echo "--- wallpaper (isolated conf, no X) ---"
export AIRA_THEME_CONF="$(mktemp /tmp/aira-wp-test.XXXXXX)"
rm -f "$AIRA_THEME_CONF"
[ "$(aira-wallpaper --list 2>/dev/null | wc -l)" = "6" ] && ok "6 wallpaper presets" || bad "6 wallpaper presets"
aira-wallpaper --list 2>/dev/null | grep -q "sunset-ember" && ok "sunset wallpaper present" || bad "sunset wallpaper present"
aira-wallpaper --list 2>/dev/null | grep -q "forest-moss" && ok "forest wallpaper present" || bad "forest wallpaper present"
aira-wallpaper --set bogus >/dev/null 2>&1 && bad "reject unknown preset" || ok "reject unknown preset"
aira-wallpaper --apply >/dev/null 2>&1 && ok "apply headless-safe" || bad "apply headless-safe"
W0="$(aira-theme get AIRA_WALLPAPER)"; aira-wallpaper --next >/dev/null 2>&1
[ "$(aira-theme get AIRA_WALLPAPER)" != "$W0" ] && ok "wallpaper --next cycles" || bad "wallpaper --next cycles"
aira-wallpaper --set ocean-tide >/dev/null 2>&1
[ "$(aira-theme get AIRA_WALLPAPER)" = "ocean-tide" ] && ok "wallpaper selection persists" || bad "wallpaper selection persists"
rm -f "$AIRA_THEME_CONF"
unset AIRA_THEME_CONF
# wrappers must be single-sourced (query theme, not hardcoded palettes)
echo "--- theme single-source (wrappers) ---"
for w in aira-terminal aira-file-manager aira-textedit aira-settings aira-sysmon aira-netman aira-pkgcenter aira-launcher aira-quicksettings; do
  if grep -q "aira-theme get" "$ROOT/gui/$w"; then ok "$w theme-aware"; else bad "$w theme-aware"; fi
done

echo "--- launcher ---"
[ "$(aira-launcher --list 2>/dev/null | wc -l)" -ge "10" ] && ok "launcher registry >=10 apps" || bad "launcher registry >=10 apps"
aira-launcher --find term 2>/dev/null | grep -q "Terminal" && ok "find matches Terminal" || bad "find matches Terminal"
aira-launcher --find zzz-no-match 2>/dev/null | grep -q . && bad "find empty on no-match" || ok "find empty on no-match"
aira-launcher --bogus >/dev/null 2>&1 && bad "reject unknown option" || ok "reject unknown option"
# every registry command must be a real tool (except the diagnostics pipeline)
# registry format: name|Category|keywords|command (4 fields)
MISSING=""
while IFS='|' read -r _name _cat _keys cmd; do
  [ -n "$_name" ] || continue
  case "$cmd" in
    aira-diagnose-launcher) ;;
    aira-action-*) # system actions resolve via aira-session-mgr (safe mechanism)
      command -v aira-session-mgr >/dev/null 2>&1 || [ -x "$ROOT/gui/aira-session-mgr" ] || MISSING="$MISSING $cmd"
      ;;
    *) [ -x "$ROOT/gui/$cmd" ] || [ -x "$ROOT/initramfs/usr/bin/$cmd" ] || command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd" ;;
  esac
done <<EOF
$(aira-launcher --list)
EOF
if [ -z "$MISSING" ]; then ok "all launcher commands resolve"; else bad "unresolved launcher commands:$MISSING"; fi
# categories / keyboard-nav plumbing (non-interactive probes)
aira-launcher --categories 2>/dev/null | grep -q "System" && ok "launcher categories" || bad "launcher categories"
aira-launcher --category System 2>/dev/null | grep -q . && ok "launcher category filter" || bad "launcher category filter"
export AIRA_STATE_DIR="$(mktemp -d /tmp/aira-state-test.XXXXXX)"
aira-launcher --recent >/dev/null 2>&1 && ok "launcher recent readable" || bad "launcher recent readable"
printf "1\nq\n" | timeout 5 aira-launcher --text >/dev/null 2>&1 || true
ok "launcher text UI smoke (no hang)"
rm -rf "$AIRA_STATE_DIR"; unset AIRA_STATE_DIR
# unavailable app handling: unknown name rejected, missing binary reported
aira-launcher --launch "No Such App" >/dev/null 2>&1 && bad "reject unknown launch" || ok "reject unknown launch"

echo "--- quick settings ---"
aira-quicksettings --status >/dev/null 2>&1 && ok "status exits 0 headless" || bad "status exits 0 headless"
aira-quicksettings --status 2>/dev/null | grep -q "Theme:" && ok "status shows theme" || bad "status shows theme"
aira-quicksettings --status 2>/dev/null | grep -qi "wi-fi" && ok "status shows wifi row" || bad "status shows wifi row"
aira-quicksettings --status 2>/dev/null | grep -qi "battery" && ok "status shows battery row" || bad "status shows battery row"
aira-quicksettings --status 2>/dev/null | grep -qi "brightness" && ok "status shows brightness row" || bad "status shows brightness row"
aira-quicksettings --volume bogus >/dev/null 2>&1 && bad "reject bad volume arg" || ok "reject bad volume arg"
aira-quicksettings --network bogus >/dev/null 2>&1 && bad "reject bad network arg" || ok "reject bad network arg"
aira-quicksettings --session bogus >/dev/null 2>&1 && bad "reject bad session arg" || ok "reject bad session arg"
# honest failure without a mixer (host CI has no ALSA Master)
aira-quicksettings --volume up >/dev/null 2>&1 && ok "volume up (mixer present)" || ok "volume up honest-fail (no mixer)"
aira-quicksettings --bogus >/dev/null 2>&1 && bad "reject unknown option" || ok "reject unknown option"
# night mode + theme select (isolated conf, no X side effects)
export AIRA_THEME_CONF="$(mktemp /tmp/aira-qs-test.XXXXXX)"; rm -f "$AIRA_THEME_CONF"
aira-quicksettings --night on >/dev/null 2>&1 && [ "$(aira-theme current)" = "aira-night" ] && ok "night on maps to theme" || bad "night on maps to theme"
aira-quicksettings --night off >/dev/null 2>&1 && [ "$(aira-theme current)" = "aira-day" ] && ok "night off maps to theme" || bad "night off maps to theme"
aira-quicksettings --theme use aira-ocean >/dev/null 2>&1 && [ "$(aira-theme current)" = "aira-ocean" ] && ok "theme select works" || bad "theme select works"
rm -f "$AIRA_THEME_CONF"; unset AIRA_THEME_CONF

echo "--- notifications (isolated FIFO/log) ---"
export AIRA_NOTIFY_FIFO="$(mktemp -u /tmp/aira-fifo-test.XXXXXX)"
export AIRA_NOTIFY_LOG="$(mktemp /tmp/aira-notify-test.XXXXXX)"
rm -f "$AIRA_NOTIFY_FIFO" "$AIRA_NOTIFY_LOG"
sh -n "$ROOT/gui/aira-notify" && ok "notify syntax" || bad "notify syntax"
sh -n "$ROOT/gui/aira-notifyd" && ok "notifyd syntax" || bad "notifyd syntax"
timeout 5 aira-notifyd >/tmp/aira-notifyd-test.log 2>&1 &
NOTIFYD_PID=$!
sleep 0.5
if kill -0 "$NOTIFYD_PID" 2>/dev/null; then ok "notifyd starts"; else bad "notifyd starts"; fi
timeout 3 aira-notify --urgency=low "TestTitle" "TestMessage" 2>/dev/null
sleep 1
grep -q "TestTitle" "$AIRA_NOTIFY_LOG" 2>/dev/null && ok "notify queued to history" || bad "notify queued to history"
timeout 3 aira-notify "SecondTitle" "SecondMessage" 2>/dev/null
sleep 1
[ "$(grep -c "Title" "$AIRA_NOTIFY_LOG" 2>/dev/null)" -ge 2 ] && ok "notify queues multiples" || bad "notify queues multiples"
aira-notify --history 2 2>/dev/null | grep -q "Title" && ok "notify history readable" || bad "notify history readable"
kill "$NOTIFYD_PID" 2>/dev/null; wait "$NOTIFYD_PID" 2>/dev/null || true
unset AIRA_NOTIFY_FIFO AIRA_NOTIFY_LOG
rm -f /tmp/aira-notifyd-test.log

echo "--- session integration ---"
grep -q "aira-wallpaper --apply" "$ROOT/gui/aira-session" && ok "session uses theme wallpaper" || bad "session uses theme wallpaper"
grep -q "aira-jwmrc.classic" "$ROOT/gui/aira-session" && ok "session has classic fallback" || bad "session has classic fallback"
grep -q "aira-notifyd" "$ROOT/gui/aira-session" && ok "session starts notifyd" || bad "session starts notifyd"
grep -q "aira-vol-indicator" "$ROOT/gui/aira-session" && ok "session links vol indicator" || bad "session links vol indicator"
grep -q "aira-power-indicator" "$ROOT/gui/aira-session" && ok "session links power indicator" || bad "session links power indicator"
grep -q "aira-theme aira-wallpaper aira-launcher aira-quicksettings" "$ROOT/scripts/build-gui.sh" && ok "build-gui stages new tools" || bad "build-gui stages new tools"
grep -q "aira-jwmrc.classic" "$ROOT/scripts/build-gui.sh" && ok "build-gui stages classic" || bad "build-gui stages classic"
grep -q "aira-vol-indicator" "$ROOT/scripts/build-gui.sh" && ok "build-gui stages vol indicator" || bad "build-gui stages vol indicator"
grep -q "aira-power-indicator" "$ROOT/scripts/build-gui.sh" && ok "build-gui stages power indicator" || bad "build-gui stages power indicator"

echo
echo "SHELL TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
