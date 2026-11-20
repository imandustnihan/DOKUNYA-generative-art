#!/usr/bin/env bash
set -euo pipefail
sdk="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
image='system-images;android-35;google_apis;x86_64'
manager="$sdk/cmdline-tools/latest/bin"
"$manager/sdkmanager" --install 'emulator' "$image"
if [[ ! -w /dev/kvm ]]; then sudo setfacl -m "u:$(id -un):rw" /dev/kvm; fi
printf 'no\n' | "$manager/avdmanager" create avd --name dokunya_ci --package "$image" --device pixel
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
