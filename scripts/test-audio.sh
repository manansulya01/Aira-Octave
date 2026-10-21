#!/usr/bin/env bash
# ALSA control regression tests: success is reported only when the tool succeeds.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIO="$ROOT/initramfs/usr/bin/aira-audio"
T="$(mktemp -d /tmp/aira-audio-test.XXXXXX)"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/empty"
cat > "$T/bin/amixer" <<'EOF'
#!/bin/sh
case "$*" in *"sget"*) exit 0 ;; esac
[ "${MOCK_AMIXER_FAIL:-0}" = 1 ] && exit 1
case "$*" in *"get Master"*) echo "Mono: Playback 70 [70%] [on]" ;; esac
exit 0
EOF
cat > "$T/bin/alsactl" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$T/bin/modprobe" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$T/bin/speaker-test" <<'EOF'
#!/bin/sh
[ "${MOCK_SPEAKER_FAIL:-0}" = 1 ] && exit 1
exit 0
EOF
cat > "$T/bin/aplay" <<'EOF'
#!/bin/sh
[ "${MOCK_APLAY_FAIL:-0}" = 1 ] && exit 1
exit 0
EOF
cat > "$T/bin/arecord" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$T/bin/"*

echo "--- start reports actual mixer result ---"
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=0 /bin/sh "$AUDIO" start >"$T/start.log" 2>&1; then
  grep -q "Audio service started" "$T/start.log" && ok "mixer start success reported" || bad "mixer start success reported"
else bad "mocked mixer start succeeds"; fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=1 /bin/sh "$AUDIO" start >"$T/start-fail.log" 2>&1; then
  bad "failed mixer start rejected"
else
  grep -q "failed to initialize mixer" "$T/start-fail.log" && ok "failed mixer start rejected" || bad "failed mixer start diagnostic"
fi
if grep -q "Audio service started" "$T/start-fail.log"; then bad "failed start does not claim success"; else ok "failed start does not claim success"; fi

echo "--- volume and mute failures propagate ---"
PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=0 /bin/sh "$AUDIO" volume >"$T/volume-get.log" 2>&1
if grep -q '^70%
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=0 /bin/sh "$AUDIO" volume 150 >/dev/null 2>&1; then bad "out-of-range volume rejected"; else ok "out-of-range volume rejected"; fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=1 /bin/sh "$AUDIO" volume 50 >"$T/volume-fail.log" 2>&1; then bad "failed volume set rejected"; else ok "failed volume set rejected"; fi
if grep -q "Volume set" "$T/volume-fail.log"; then bad "failed volume set does not claim success"; else ok "failed volume set does not claim success"; fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=1 /bin/sh "$AUDIO" mute >"$T/mute-fail.log" 2>&1; then bad "failed mute rejected"; else ok "failed mute rejected"; fi
if grep -q '^Muted$' "$T/mute-fail.log"; then bad "failed mute does not claim success"; else ok "failed mute does not claim success"; fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=1 /bin/sh "$AUDIO" unmute >"$T/unmute-fail.log" 2>&1; then bad "failed unmute rejected"; else ok "failed unmute rejected"; fi
if grep -q '^Unmuted$' "$T/unmute-fail.log"; then bad "failed unmute does not claim success"; else ok "failed unmute does not claim success"; fi

echo "--- test tone success/failure is truthful ---"
if PATH="$T/bin:/usr/bin:/bin" MOCK_SPEAKER_FAIL=1 MOCK_APLAY_FAIL=1 /bin/sh "$AUDIO" test >"$T/tone-fail.log" 2>&1; then
  bad "failed test tone rejected"
else
  grep -q "test tone failed" "$T/tone-fail.log" && ok "failed test tone rejected" || bad "failed test tone diagnostic"
fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_SPEAKER_FAIL=0 MOCK_APLAY_FAIL=0 /bin/sh "$AUDIO" test >"$T/tone-ok.log" 2>&1; then
  grep -q "Test tone played" "$T/tone-ok.log" && ok "successful test tone reported" || bad "successful test tone reported"
else bad "successful test tone accepted"; fi

echo "--- missing runtime tool fails explicitly ---"
if PATH="$T/empty" /bin/sh "$AUDIO" start >"$T/no-tools.log" 2>&1; then
  bad "missing amixer rejected"
else
  grep -q "required ALSA tool 'amixer' is not installed" "$T/no-tools.log" && ok "missing amixer rejected" || bad "missing amixer diagnostic"
fi

echo
echo "AUDIO TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
 "$T/volume-get.log"; then
  ok "volume query returns mixer value"
else
  bad "volume query returns mixer value"
  sed -n '1,20p' "$T/volume-get.log"
fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=0 /bin/sh "$AUDIO" volume 150 >/dev/null 2>&1; then bad "out-of-range volume rejected"; else ok "out-of-range volume rejected"; fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=1 /bin/sh "$AUDIO" volume 50 >"$T/volume-fail.log" 2>&1; then bad "failed volume set rejected"; else ok "failed volume set rejected"; fi
if grep -q "Volume set" "$T/volume-fail.log"; then bad "failed volume set does not claim success"; else ok "failed volume set does not claim success"; fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=1 /bin/sh "$AUDIO" mute >"$T/mute-fail.log" 2>&1; then bad "failed mute rejected"; else ok "failed mute rejected"; fi
if grep -q '^Muted$' "$T/mute-fail.log"; then bad "failed mute does not claim success"; else ok "failed mute does not claim success"; fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=1 /bin/sh "$AUDIO" unmute >"$T/unmute-fail.log" 2>&1; then bad "failed unmute rejected"; else ok "failed unmute rejected"; fi
if grep -q '^Unmuted$' "$T/unmute-fail.log"; then bad "failed unmute does not claim success"; else ok "failed unmute does not claim success"; fi

echo "--- test tone success/failure is truthful ---"
if PATH="$T/bin:/usr/bin:/bin" MOCK_SPEAKER_FAIL=1 MOCK_APLAY_FAIL=1 /bin/sh "$AUDIO" test >"$T/tone-fail.log" 2>&1; then
  bad "failed test tone rejected"
else
  grep -q "test tone failed" "$T/tone-fail.log" && ok "failed test tone rejected" || bad "failed test tone diagnostic"
fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_SPEAKER_FAIL=0 MOCK_APLAY_FAIL=0 /bin/sh "$AUDIO" test >"$T/tone-ok.log" 2>&1; then
  grep -q "Test tone played" "$T/tone-ok.log" && ok "successful test tone reported" || bad "successful test tone reported"
else bad "successful test tone accepted"; fi

echo "--- missing runtime tool fails explicitly ---"
if PATH="$T/empty" /bin/sh "$AUDIO" start >"$T/no-tools.log" 2>&1; then
  bad "missing amixer rejected"
else
  grep -q "required ALSA tool 'amixer' is not installed" "$T/no-tools.log" && ok "missing amixer rejected" || bad "missing amixer diagnostic"
fi

echo
echo "AUDIO TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
