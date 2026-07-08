# 2026-07-08: Counter Android APK Shell

- **Agent**: Codex GPT-5
- **Goal**: Complete Android support by following the native-stub/CMake style
  used by `moonbit-community/tonyfettes-raylib`, and answer whether an APK can
  be built.
- **Outcome**: The Counter Android debug APK builds locally with real Android
  Skia. Android runtime support still remains pending on device or emulator
  smoke evidence.

## Summary

Added an app-owned Counter Android shell around the existing
`examples/counter/android_skia` embedded session. The new path exports MoonBit C
entrypoints, compiles JNI/CMake native glue with the Android NDK, packages a
Java `SurfaceView` activity, and preserves the Android route as experimental
until matching runtime evidence exists.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `examples/counter/android_skia` | Added native exports and pointer dispatch entrypoint. | Let JNI call the MoonBit embedded session directly. |
| `examples/counter/android_app` | Added Android manifest, Java Activity, JNI, CMake, runtime compatibility source, Gradle project files, and README. | Provide an APK shell that owns Activity/Surface lifecycle. |
| `scripts/build-counter-android-apk.sh` | Added direct Android SDK/NDK debug APK builder with real dynamic Skia packaging and fallback Skia smoke mode. | Build APKs without requiring a checked-in Gradle wrapper. |
| `docs/`, `AGENTS.md`, `skills/` | Documented APK build commands and evidence boundaries. | Keep Android support guidance synchronized. |

## Key Decisions

- Keep Android on the embedded-session route: Activity/JNI owns lifecycle and
  `ANativeWindow`, while `moui/backend/android` and `moui/backend/android/skia`
  own host/session and presenter contracts.
- Use a direct SDK/NDK packaging script because the local environment had SDK,
  NDK, CMake, and Java but no system Gradle or repository Gradle wrapper.
- Default the APK script to dynamic Android Skia so the APK can package
  `libskia.so` beside `libmoui_counter_android.so`.
- Treat `--fallback-skia` APK output as packaging evidence only. Android
  runtime support still requires device/emulator smoke.

## Discoveries

- MoonBit native `link.native.exports` emits unmangled C wrappers usable from
  JNI.
- MoonBit-generated native C defines a `main`, so the Android shared-library
  build renames it at compile time and initializes `moonbit_runtime_init` plus
  `moonbit_init` from JNI.
- MoonBit runtime currently calls `getentropy`; Android API 23 needs a local
  compatibility implementation backed by `arc4random_buf`.
- The real Skia APK must package both `libskia.so` and the NDK
  `libc++_shared.so`; otherwise the Android native loader can fail even when
  the desktop-side APK build and signing steps pass.

## Validation

Local validation used an Android SDK installed outside the repository. The
portable form of the commands is:

```sh
bash -n scripts/build-counter-android-apk.sh
ANDROID_HOME=/path/to/Android/Sdk ANDROID_NDK_HOME=/path/to/Android/Sdk/ndk/25.2.9519653 scripts/build-counter-android-apk.sh --fallback-skia --prepare-only
ANDROID_HOME=/path/to/Android/Sdk ANDROID_NDK_HOME=/path/to/Android/Sdk/ndk/25.2.9519653 scripts/build-counter-android-apk.sh --fallback-skia
ANDROID_HOME=/path/to/Android/Sdk ANDROID_NDK_HOME=/path/to/Android/Sdk/ndk/25.2.9519653 scripts/build-counter-android-apk.sh
/path/to/Android/Sdk/build-tools/<installed-version>/apksigner verify --verbose artifacts/android/counter/app-debug.apk
```

The real-Skia APK was written to `artifacts/android/counter/app-debug.apk`.
`unzip -l` shows the APK contains:

```text
lib/arm64-v8a/libmoui_counter_android.so
lib/arm64-v8a/libskia.so
lib/arm64-v8a/libc++_shared.so
```

`apksigner verify --verbose` passed with v1, v2, and v3 signing schemes.

## Follow-Up

- [ ] Record matching Android device/emulator first-frame, pointer, lifecycle,
      and pending-service evidence before marking Android runtime support
      passed.
