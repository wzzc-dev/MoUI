# Android Support

Android support is currently an experimental embedded native scaffold. MoUI does
not own an Android `Activity` or app event loop yet. The Android layer owns the
shell, supplies an `ANativeWindow`, and forwards lifecycle, resize, input, and
redraw callbacks into MoUI.

## Status

| Area | Current state | Evidence boundary |
| --- | --- | --- |
| Host contract | Scaffolded in `moui/backend/android` | Package tests prove protocol behavior only. |
| Skia provider | Scaffolded in `moui/backend/android/skia` | Provider/preflight checks prove wiring, not device pixels. |
| Counter entrypoint | `examples/counter/android_skia` exports thin native hooks | Compile/check evidence only. |
| APK shell | `examples/counter/android_app` plus `scripts/build-counter-android-apk.sh` | Packaging evidence; fallback APK is not runtime proof. |
| Runtime support claim | Pending | Requires a non-fallback APK plus matching device/emulator smoke. |

## Ownership

- `moui/backend/android` owns `AndroidSurfaceHandle`,
  `AndroidRendererProvider`, readiness summaries, and `AndroidRuntimeSession`.
- `moui/backend/android/skia` wraps `moui/render/skia` in a
  `HostWindowRenderer` and presents copied RGBA frames to an `ANativeWindow`
  when compiled for Android.
- `examples/counter/android_skia` is the thin MoonBit entrypoint for JNI/CMake.
  Its attach/resize/pointer/render/detach exports stay small so the Android app
  can own the shell.
- `examples/counter/android_app` owns the experimental Java `Activity`,
  `SurfaceView` lifecycle, touch forwarding, JNI `ANativeWindow` acquisition,
  CMake wiring, MoonBit-generated C, MoonBit runtime, Android presenter, and
  `moui_skia/native` stubs.

## Focused Checks

Use fallback-safe checks for routine scaffold work:

```sh
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/android --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/android/skia --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/counter/android_skia --target native
scripts/build-counter-android-apk.sh --fallback-skia
```

These checks are useful before handoff, but none of them prove Android runtime
presentation.

## Skia Cross-Build

Use explicit Skia prebuild variables when cross-building the real native route:

```sh
MOUI_SKIA_PLATFORM=android \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=static \
moon check examples/counter/android_skia --target native
```

`MOUI_SKIA_PLATFORM=android` selects the Android asset from
`moui_skia/skia-provider-lock.json` instead of inferring the desktop host
platform. `MOUI_SKIA_ARCH` accepts `arm64`, `x64`, or `riscv64`, matching the
locked provider manifest. `MOUI_SKIA_SKIA_INCLUDE` and
`MOUI_SKIA_SKIA_LIB_DIR` may override the release provider when an Android build
system has already staged Skia.

## SDK And NDK Setup

MoUI does not require a repository-private Android SDK location. Install the
SDK/NDK with official Android tools, then point `ANDROID_HOME` or
`ANDROID_SDK_ROOT` at that SDK root. Do not document machine-local SDK paths as
project requirements.

The repository helper installs the official command-line tools and required SDK
packages. It requires a JDK on `PATH` because `sdkmanager`, `javac`, and
`keytool` are used. APK builds additionally require `jlink`, so point
`JAVA_HOME` at a complete JDK rather than a stripped runtime. Use Java 17 or
newer for Android Gradle Plugin 9.x; Java 21 is the recommended local default.
Java 11 is too old for the APK build, while very new JDKs may be ahead of
Gradle/Groovy support.

```sh
scripts/setup-android-sdk.sh --accept-licenses
eval "$(scripts/setup-android-sdk.sh --print-env)"
```

By default this installs under `~/Library/Android/sdk` on macOS and
`~/Android/Sdk` on Linux. Use
`scripts/setup-android-sdk.sh --android-home /path/to/Android/Sdk` for a
custom SDK root.

Manual setup should install:

- Android SDK Platform 35
- Android SDK Build-Tools 35.0.0
- Android SDK Platform-Tools
- NDK 25.2.9519653 or a compatible side-by-side NDK
- CMake 3.22.1

Example command-line setup:

```sh
export ANDROID_HOME="$HOME/Android/Sdk"
mkdir -p "$ANDROID_HOME/cmdline-tools"
# Unzip the official commandlinetools package so that this path exists:
#   "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmake/3.22.1/bin:$PATH"

sdkmanager --licenses
sdkmanager --install \
  "platform-tools" \
  "platforms;android-35" \
  "build-tools;35.0.0" \
  "cmake;3.22.1" \
  "ndk;25.2.9519653"
```

The APK script auto-selects the latest NDK under `$ANDROID_HOME/ndk` when
`ANDROID_NDK_HOME` is not set. Set `ANDROID_NDK_HOME` only when a specific NDK
must be pinned.

## Mobile APK Builds

Android APK builds now use the shared mobile Gradle route. The app-specific
shells under `examples/counter/android_app` and
`examples/component_gallery/android_app` consume app-facing metadata from
`examples/<app>/mobile.json` plus package-published compatibility contracts
from `moui/mobile/build-contracts.json`. The reusable Gradle plugin, Java
Activity, JNI, CMake, and copyable project template live under `moui/mobile`
so external apps can use the same route from the published `wzzc-dev/moui`
package. A Gradle pre-build task generates MoonBit C plus Skia flags, compiles
the shared JNI/CMake template, and lets Gradle package/sign the debug APK.

Build the experimental Counter debug APK from the repository root:

```sh
ANDROID_HOME=/path/to/Android/Sdk \
scripts/build-mobile-android-apk.sh --app counter
```

Build Component Gallery with the same route:

```sh
ANDROID_HOME=/path/to/Android/Sdk \
scripts/build-mobile-android-apk.sh --app component_gallery
```

When multiple side-by-side NDK versions are installed, pin the intended one:

```sh
ANDROID_HOME=/path/to/Android/Sdk \
ANDROID_NDK_HOME=/path/to/Android/Sdk/ndk/25.2.9519653 \
scripts/build-mobile-android-apk.sh --app counter
```

The default APK path resolves the locked Android Skia provider through
`moui_skia/build.js`, uses the dynamic Android Skia artifact so native
dependencies can be packaged, builds the app's native library, packages the
shared Java `SurfaceView` glue, and writes:

```text
artifacts/android/counter/app-debug.apk
artifacts/android/component_gallery/app-debug.apk
```

The default `arm64-v8a` APK includes `libmoui_counter_android.so`, `libskia.so`,
and the NDK `libc++_shared.so`. Set `MOUI_SKIA_LINK_MODE=static` only for
explicit static-link experiments.

For packaging-only smoke, use:

```sh
scripts/build-counter-android-apk.sh --fallback-skia
scripts/build-component-gallery-android-apk.sh --fallback-skia
```

`--fallback-skia` validates MoonBit C generation, JNI, CMake,
Java/resource packaging, and debug signing. It reports native Skia unavailable
and must not be used as first-frame runtime evidence.

The old app-specific build scripts remain compatibility wrappers over
`scripts/build-mobile-android-apk.sh --app ...`.

For an external app, copy `moui/mobile/android/template` to `android_app`, copy
`moui/mobile/template.mobile.json` to `mobile.json`, fill in the app id and
`android.native` export contract, then run the package-published script from
the app workspace:

```sh
.mooncakes/wzzc-dev/moui/scripts/mobile/build-android-apk.sh \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --app my_app \
  --app-config "$PWD/mobile.json" \
  --android-project "$PWD/android_app"
```

## Runtime Evidence Required

A passed Android runtime claim requires a non-fallback APK plus matching
device/emulator evidence for at least:

- Activity/Surface lifecycle creating and disposing an `AndroidRuntimeSession`.
- `ANativeWindow` presentation with nonblank first-frame pixels.
- Resize and pointer callbacks reaching `HostRuntimeDriver`.
- Text input/IME observations or explicit pending status.
- Clipboard, accessibility, async image, and packaging observations or explicit
  pending status.

Until those observations exist, describe Android as an experimental embedded
scaffold, not as a passed platform.

The checked smoke catalog now contains release/manual Android mobile runtime
suites. After a non-fallback build, record and validate evidence with:

```sh
node scripts/record-mobile-runtime-smoke.mjs --platform android --app counter --require-passed
node scripts/record-mobile-runtime-smoke.mjs --platform android --app component_gallery --require-passed
```
