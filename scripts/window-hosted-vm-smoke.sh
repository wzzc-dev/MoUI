#!/usr/bin/env bash
# Window-hosted MoUI mobile validation facade.
# Default: host-sim suite (always runnable).
# Optional VM legs when tools/env present:
#   WINDOW_HOSTED_ANDROID_AVD=1   attempt adb/emulator checks
#   WINDOW_HOSTED_IOS_SIM=1       attempt xcrun simctl checks
#   WINDOW_HOSTED_HARMONYOS_HVD=1 attempt hdc checks
set -euo pipefail
# Serial VM policy: never run Android AVD + iOS Simulator + HVD concurrently.
# Callers should enable at most one of WINDOW_HOSTED_ANDROID_AVD / IOS_SIM / HARMONYOS_HVD.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash "$ROOT/scripts/window-hosted-hostsim-smoke.sh"

android_avd() {
  if [[ "${WINDOW_HOSTED_ANDROID_AVD:-}" != "1" ]]; then
    echo "Android AVD leg skipped (set WINDOW_HOSTED_ANDROID_AVD=1)."
    return 0
  fi
  if ! command -v adb >/dev/null 2>&1; then
    echo "adb not found; Android AVD leg failed" >&2
    return 1
  fi
  if ! adb devices | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then
    echo "No Android device/emulator online (adb devices)." >&2
    echo "Start AVD per docs/android-support.md then re-run." >&2
    return 1
  fi
  APK="$ROOT/artifacts/window-hosted-android/app-debug.apk"
  if [[ ! -f "$APK" ]]; then
    echo "APK missing at $APK — run scripts/build-window-hosted-android-apk.sh first" >&2
    return 1
  fi
  PKG="dev.wzzc.window.hosted.counter"
  adb install -r "$APK"
  adb shell am force-stop "$PKG" >/dev/null 2>&1 || true
  adb shell am start -n "$PKG/dev.wzzc.window.template.HostedActivity"
  sleep 3
  if ! adb shell pidof "$PKG" >/dev/null 2>&1; then
    echo "window-hosted counter process not running after launch" >&2
    adb logcat -d | tail -80 >&2 || true
    return 1
  fi
  echo "Android AVD window-hosted: install+launch ok (pid=$(adb shell pidof "$PKG" | tr -d '\r'))"
  return 0
}

ios_sim() {
  if [[ "${WINDOW_HOSTED_IOS_SIM:-}" != "1" ]]; then
    echo "iOS Simulator leg skipped (set WINDOW_HOSTED_IOS_SIM=1)."
    return 0
  fi
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun not found; iOS Simulator leg failed" >&2
    return 1
  fi
  APP="$ROOT/artifacts/window-hosted-ios/WindowHostedCounter.app"
  if [[ ! -d "$APP" ]]; then
    echo "iOS app missing at $APP — run scripts/build-window-hosted-ios-sim-app.sh first" >&2
    return 1
  fi
  UDID="${MOUI_IOS_DEVICE:-}"
  if [[ -z "$UDID" ]]; then
    UDID=$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $(NF-1); exit}')
  fi
  if [[ -z "$UDID" ]]; then
    echo "No iOS simulator UDID found" >&2
    return 1
  fi
  xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  BUNDLE="dev.wzzc.window.hosted.counter"
  xcrun simctl install "$UDID" "$APP"
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  if ! xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null; then
    echo "simctl launch failed for $BUNDLE on $UDID" >&2
    return 1
  fi
  echo "iOS Simulator window-hosted: install+launch ok (udid=$UDID)"
  return 0
}

harmony_hvd() {
  if [[ "${WINDOW_HOSTED_HARMONYOS_HVD:-}" != "1" ]]; then
    echo "HarmonyOS HVD leg skipped (set WINDOW_HOSTED_HARMONYOS_HVD=1)."
    return 0
  fi
  if ! command -v hdc >/dev/null 2>&1; then
    echo "hdc not found; HVD leg failed" >&2
    return 1
  fi
  bash "$ROOT/scripts/build-window-hosted-harmonyos-hap.sh"
  # Device install only when a non-empty target exists.
  target=$(hdc list targets 2>/dev/null | awk 'NF && $1 !~ /\[Empty\]/{print $1; exit}' || true)
  if [[ -z "${target:-}" ]]; then
    echo "HarmonyOS HVD: no device target; host-sim + packaging status recorded (not a fake device pass)."
    return 0
  fi
  echo "HarmonyOS device $target online; HAP install for window-hosted not yet implemented — fail closed."
  return 1
}

android_avd
ios_sim
harmony_hvd
echo "window-hosted vm facade: ok (see host-sim evidence; packaging/VM install still path-triggered)"
