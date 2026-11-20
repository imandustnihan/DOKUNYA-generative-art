#!/usr/bin/env bash
set -euo pipefail
sdk="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
image='system-images;android-35;google_apis;x86_64'
manager="$sdk/cmdline-tools/latest/bin"
"$manager/sdkmanager" --install 'emulator' "$image"
if [[ ! -w /dev/kvm ]]; then sudo setfacl -m "u:$(id -un):rw" /dev/kvm; fi
# Both avdmanager and the emulator must resolve the exact same AVD home.
# Hosted runners may set ANDROID_SDK_HOME or a nonstandard HOME, which previously
# caused "Unknown AVD name [dokunya_ci]" even after successful AVD creation.
export ANDROID_AVD_HOME="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/dokunya-ci-avds"
mkdir -p "$ANDROID_AVD_HOME"
printf 'no\n' | "$manager/avdmanager" create avd --name dokunya_ci --package "$image" --device pixel

# Fail with actionable diagnostics instead of silently treating an AVD path
# mismatch as an application test failure.
if [[ ! -f "$ANDROID_AVD_HOME/dokunya_ci.ini" ]]; then
  echo "::error::AVD configuration was not written to $ANDROID_AVD_HOME"
  find "$ANDROID_AVD_HOME" "${HOME:-/tmp}/.android" -maxdepth 3 -name '*.ini' -print 2>/dev/null || true
  exit 1
fi
if ! "$sdk/emulator/emulator" -list-avds | grep -Fxq dokunya_ci; then
  echo "::error::Emulator cannot discover the AVD created by avdmanager"
  "$sdk/emulator/emulator" -list-avds || true
  exit 1
fi

adb="$sdk/platform-tools/adb"
"$sdk/emulator/emulator" -avd dokunya_ci -port 5554 -no-window -no-audio -no-snapshot -no-boot-anim -gpu swiftshader_indirect > "$RUNNER_TEMP/dokunya-emulator.log" 2>&1 &
emulator_pid=$!
trap '"$adb" -s emulator-5554 emu kill >/dev/null 2>&1 || true' EXIT
for attempt in {1..90}; do
  if ! kill -0 "$emulator_pid" 2>/dev/null; then cat "$RUNNER_TEMP/dokunya-emulator.log"; exit 1; fi
  if [[ $("$adb" -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r') == 1 ]]; then
    "$adb" -s emulator-5554 shell input keyevent 82
    flutter test integration_test/studio_flow_test.dart -d emulator-5554 --reporter expanded
    exit 0
  fi
  sleep 4
done
tail -50 "$RUNNER_TEMP/dokunya-emulator.log"
exit 1
