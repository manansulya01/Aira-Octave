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
case "$*" in
  *"sget"*)
    [ "${MOCK_NO_MIXER:-0}" = 1 ] && exit 1
    exit 0 ;;
esac
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
if [ -n "${MOCK_PRINT_ALSA_CONFIG:-}" ]; then
  printf 'ALSA_CONFIG_PATH=%s\nALSA_CONFIG_DIR=%s\nALSA_PLUGIN_DIR=%s\n' "${ALSA_CONFIG_PATH:-}" "${ALSA_CONFIG_DIR:-}" "${ALSA_PLUGIN_DIR:-}"
fi
[ "${MOCK_SPEAKER_FAIL:-0}" = 1 ] && exit 1
exit 0
EOF
cat > "$T/bin/aplay" <<'EOF'
#!/bin/sh
case "$*" in
  -l)
    [ "${MOCK_NO_PLAYBACK:-0}" = 1 ] && exit 1
    echo "card 0: Test [Test Audio], device 0: Playback [Playback]"
    exit 0 ;;
esac
[ "${MOCK_APLAY_FAIL:-0}" = 1 ] && exit 1
exit 0
EOF
cat > "$T/bin/arecord" <<'EOF'
#!/bin/sh
exit 0
EOF
printf '00-00: HDA Analog : playback 1\n' > "$T/asound-pcm"
: > "$T/no-asound-pcm"
chmod +x "$T/bin/"*

echo "--- ALSA staged configuration paths can be overridden ---"
if PATH="$T/bin:/usr/bin:/bin" AIRA_ALSA_CONFIG_PATH="$T/alsa.conf" AIRA_ALSA_CONFIG_DIR="$T/alsa" AIRA_ALSA_PLUGIN_DIR="$T/plugins" MOCK_PRINT_ALSA_CONFIG=1 /bin/sh "$AUDIO" test >"$T/alsa-paths.log" 2>&1; then
  grep -q "ALSA_CONFIG_PATH=$T/alsa.conf" "$T/alsa-paths.log" &&
  grep -q "ALSA_CONFIG_DIR=$T/alsa" "$T/alsa-paths.log" &&
  grep -q "ALSA_PLUGIN_DIR=$T/plugins" "$T/alsa-paths.log" && ok "ALSA config and plugin path overrides exported" || bad "ALSA config and plugin path overrides exported"
else bad "ALSA config path override test command"; fi

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

echo "--- playback-only devices without mixer controls ---"
if PATH="$T/bin:/usr/bin:/bin" MOCK_NO_MIXER=1 /bin/sh "$AUDIO" start >"$T/no-mixer.log" 2>&1; then
  grep -q "playback service started (degraded: no mixer controls)" "$T/no-mixer.log" && ok "playback-only device starts with explicit degraded status" || bad "playback-only degraded status"
else bad "playback-only device starts without mixer controls"; fi
if PATH="$T/bin:/usr/bin:/bin" AIRA_ASOUND_PCM_PATH="$T/asound-pcm" MOCK_NO_MIXER=1 MOCK_NO_PLAYBACK=1 /bin/sh "$AUDIO" start >"$T/proc-playback.log" 2>&1; then
  grep -q "playback service started (degraded: no mixer controls)" "$T/proc-playback.log" && ok "ALSA proc inventory detects playback without mixer or aplay enumeration" || bad "ALSA proc playback degraded status"
else bad "ALSA proc inventory playback fallback"; fi
if PATH="$T/bin:/usr/bin:/bin" AIRA_ASOUND_PCM_PATH="$T/no-asound-pcm" MOCK_NO_MIXER=1 MOCK_NO_PLAYBACK=1 /bin/sh "$AUDIO" start >"$T/no-audio-device.log" 2>&1; then
  bad "missing mixer and playback device rejected"
else
  grep -q "no usable mixer controls or playback device" "$T/no-audio-device.log" && ok "missing mixer and playback device rejected" || bad "missing playback diagnostic"
fi

echo "--- stop reports the actual mixer result ---"
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=0 /bin/sh "$AUDIO" stop >"$T/stop.log" 2>&1; then
  grep -q "Audio service stopped" "$T/stop.log" && ok "successful stop reported" || bad "successful stop reported"
else bad "mocked stop succeeds"; fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=1 /bin/sh "$AUDIO" stop >"$T/stop-fail.log" 2>&1; then
  bad "failed stop rejected"
else
  grep -q "failed to mute" "$T/stop-fail.log" && ok "failed stop rejected" || bad "failed stop diagnostic"
fi
if grep -q "Audio service stopped" "$T/stop-fail.log"; then bad "failed stop does not claim success"; else ok "failed stop does not claim success"; fi

echo "--- volume and mute failures propagate ---"
PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=0 /bin/sh "$AUDIO" volume >"$T/volume-get.log" 2>&1
if grep -Fqx "70%" "$T/volume-get.log"; then
  ok "volume query returns mixer value"
else
  bad "volume query returns mixer value"
  sed -n '1,20p' "$T/volume-get.log"
fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=0 /bin/sh "$AUDIO" volume 150 >/dev/null 2>&1; then bad "out-of-range volume rejected"; else ok "out-of-range volume rejected"; fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=1 /bin/sh "$AUDIO" volume 50 >"$T/volume-fail.log" 2>&1; then bad "failed volume set rejected"; else ok "failed volume set rejected"; fi
if grep -q "Volume set" "$T/volume-fail.log"; then bad "failed volume set does not claim success"; else ok "failed volume set does not claim success"; fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=1 /bin/sh "$AUDIO" mute >"$T/mute-fail.log" 2>&1; then bad "failed mute rejected"; else ok "failed mute rejected"; fi
if grep -Fqx "Muted" "$T/mute-fail.log"; then bad "failed mute does not claim success"; else ok "failed mute does not claim success"; fi
if PATH="$T/bin:/usr/bin:/bin" MOCK_AMIXER_FAIL=1 /bin/sh "$AUDIO" unmute >"$T/unmute-fail.log" 2>&1; then bad "failed unmute rejected"; else ok "failed unmute rejected"; fi
if grep -Fqx "Unmuted" "$T/unmute-fail.log"; then bad "failed unmute does not claim success"; else ok "failed unmute does not claim success"; fi

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
  grep -q "required ALSA tool" "$T/no-tools.log" && ok "missing amixer rejected" || bad "missing amixer diagnostic"
fi

echo "--- QEMU audio backend exposes playback rather than output-only codec ---"
if grep -Fq -- '-device hda-duplex,audiodev=audio0' "$ROOT/scripts/boot-qemu.sh" &&
   ! grep -Fq -- '-device hda-output,audiodev=audio0' "$ROOT/scripts/boot-qemu.sh"; then
  ok "QEMU audio test uses duplex HDA codec"
else
  bad "QEMU audio test uses duplex HDA codec"
fi

echo
echo "AUDIO TEST: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
