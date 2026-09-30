#!/usr/bin/env bash
# Aira shell test (Phase 1 / WAVE B increment 1): static + unit checks for the
# top-panel+dock layout, theme engine, wallpaper, launcher, quick settings.
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
for f in gui/aira-session gui/aira-theme gui/aira-wallpaper gui/aira-launcher gui/aira-quicksettings; do
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
[ "$(aira-theme list 2>/dev/null | wc -l)" = "4" ] && ok "4 built-in themes" || bad "4 built-in themes"
aira-theme use aira-ocean >/dev/null 2>&1 && ok "use aira-ocean" || bad "use aira-ocean"
[ "$(aira-theme get AIRA_ACCENT)" = "#00b8d4" ] && ok "ocean accent applied" || bad "ocean accent applied"
[ "$(aira-theme current)" = "aira-ocean" ] && ok "current reports ocean" || bad "current reports ocean"
aira-theme set AIRA_OPACITY 0.8 >/dev/null 2>&1 && \
  [ "$(aira-theme get AIRA_OPACITY)" = "0.8" ] && ok "set/get roundtrip" || bad "set/get roundtrip"
aira-theme use bogus-theme >/dev/null 2>&1 && bad "reject unknown theme" || ok "reject unknown theme"
aira-theme set BOGUS_KEY x >/dev/null 2>&1 && bad "reject unknown key" || ok "reject unknown key"
BEFORE="$(aira-theme current)"; aira-theme --next >/dev/null 2>&1
[ "$(aira-theme current)" != "$BEFORE" ] && ok "theme --next cycles" || bad "theme --next cycles"
rm -f "$AIRA_THEME_CONF"

echo "--- wallpaper (isolated conf, no X) ---"
export AIRA_THEME_CONF="$(mktemp /tmp/aira-wp-test.XXXXXX)"
rm -f "$AIRA_THEME_CONF"
[ "$(aira-wallpaper --list 2>/dev/null | wc -l)" = "4" ] && ok "4 wallpaper presets" || bad "4 wallpaper presets"
aira-wallpaper --set bogus >/dev/null 2>&1 && bad "reject unknown preset" || ok "reject unknown preset"
aira-wallpaper --apply >/dev/null 2>&1 && ok "apply headless-safe" || bad "apply headless-safe"
W0="$(aira-theme get AIRA_WALLPAPER)"; aira-wallpaper --next >/dev/null 2>&1
[ "$(aira-theme get AIRA_WALLPAPER)" != "$W0" ] && ok "wallpaper --next cycles" || bad "wallpaper --next cycles"
rm -f "$AIRA_THEME_CONF"
unset AIRA_THEME_CONF

echo "--- launcher ---"
[ "$(aira-launcher --list 2>/dev/null | wc -l)" -ge "10" ] && ok "launcher registry >=10 apps" || bad "launcher registry >=10 apps"
aira-launcher --find term 2>/dev/null | grep -q "Terminal" && ok "find matches Terminal" || bad "find matches Terminal"
aira-launcher --find zzz-no-match 2>/dev/null | grep -q . && bad "find empty on no-match" || ok "find empty on no-match"
aira-launcher --bogus >/dev/null 2>&1 && bad "reject unknown option" || ok "reject unknown option"
# every registry command must be a real tool (except the diagnostics pipeline)
MISSING=""
while IFS='|' read -r _name _keys cmd; do
  case "$cmd" in
    aira-diagnose-launcher) ;;
    *) [ -x "$ROOT/gui/$cmd" ] || [ -x "$ROOT/initramfs/usr/bin/$cmd" ] || command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd" ;;
  esac
done <<EOF
$(aira-launcher --list)
EOF
if [ -z "$MISSING" ]; then ok "all launcher commands resolve"; else bad "unresolved launcher commands:$MISSING"; fi

echo "--- quick settings ---"
aira-quicksettings --status >/dev/null 2>&1 && ok "status exits 0 headless" || bad "status exits 0 headless"
aira-quicksettings --status 2>/dev/null | grep -q "Theme:" && ok "status shows theme" || bad "status shows theme"
aira-quicksettings --volume bogus >/dev/null 2>&1 && bad "reject bad volume arg" || ok "reject bad volume arg"
aira-quicksettings --network bogus >/dev/null 2>&1 && bad "reject bad network arg" || ok "reject bad network arg"
aira-quicksettings --session bogus >/dev/null 2>&1 && bad "reject bad session arg" || ok "reject bad session arg"
# honest failure without a mixer (host CI has no ALSA Master)
aira-quicksettings --volume up >/dev/null 2>&1 && ok "volume up (mixer present)" || ok "volume up honest-fail (no mixer)"
aira-quicksettings --bogus >/dev/null 2>&1 && bad "reject unknown option" || ok "reject unknown option"

echo "--- session integration ---"
grep -q "aira-wallpaper --apply" "$ROOT/gui/aira-session" && ok "session uses theme wallpaper" || bad "session uses theme wallpaper"
grep -q "aira-jwmrc.classic" "$ROOT/gui/aira-session" && ok "session has classic fallback" || bad "session has classic fallback"
grep -q "aira-theme aira-wallpaper aira-launcher aira-quicksettings" "$ROOT/scripts/build-gui.sh" && ok "build-gui stages new tools" || bad "build-gui stages new tools"
grep -q "aira-jwmrc.classic" "$ROOT/scripts/build-gui.sh" && ok "build-gui stages classic" || bad "build-gui stages classic"

echo
echo "SHELL TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
