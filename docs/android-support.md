# Android Support

Android support is currently an experimental embedded native route. The shared
mobile template owns the canonical Kotlin `MoUIActivity`/`MoUISurfaceView`,
supplies an `ANativeWindow`, drives frames with `Choreographer`, and forwards
lifecycle, resize, pointer, IME, clipboard, accessibility, and revisioned
PlatformView snapshots into MoUI. `MoUIActivity` extends AndroidX
`ComponentActivity`; its `FrameLayout` keeps the MoUI surface below a native
PlatformView overlay.

## Status

| Area | Current state | Evidence boundary |
| --- | --- | --- |
| Host contract | Scaffolded in `moui/backend/android` | Package tests prove protocol behavior only. |
| Platform services | `InputConnection`, text/image `ClipboardManager`, a private clipboard `ContentProvider`, virtual `AccessibilityNodeProvider`, and PlatformView overlay are wired through `MobileHostChannel` | Full IME, cross-app PNG, TalkBack tree/focus/action, and PlatformView device evidence pending on the managed shell. |
| Frame pacing | Input/resize request redraw; presentation runs from `Choreographer` frame ticks | 60/120 Hz device pacing evidence pending. |
| Skia provider | Scaffolded in `moui/backend/android/skia` | Provider/preflight checks prove wiring, not device pixels. |
| Counter entrypoint | `examples/counter/android_skia` exports thin native hooks | Compile/check evidence only. |
| APK shell | Package-owned Kotlin/AndroidX managed shell plus app-owned Gradle metadata under `examples/*/android_app` | Packaging evidence; fallback APK is not runtime proof. |
| First-frame runtime evidence | Non-fallback Component Gallery APK on HUAWEI SCM-W09 device; nonblank first-frame screenshot in `resource/screenshots/android-componentgallery.jpg` (2026-07-10) | First-frame pixels proven. |
| Runtime support claim | Release N Java shell reached **L2 `passed`** on an emulator (Component Gallery, 2026-07-15); the canonical managed shell needs a fresh matching-device run | Historical evidence does not automatically promote the replacement shell. Re-run `scripts/android-mobile-runtime-evidence.sh` without shell-side probes before claiming managed-shell runtime support. |

## Ownership

- `moui/backend/android` owns `AndroidSurfaceHandle`,
  `AndroidRendererProvider`, readiness summaries, and `AndroidRuntimeSession`.
- `moui/backend/android/skia` wraps `moui/render/skia` in a
  `HostWindowRenderer` and presents copied RGBA frames to an `ANativeWindow`
  when compiled for Android.
- `examples/counter/android_skia` is the thin MoonBit entrypoint for JNI/CMake.
  Its attach/resize/pointer/render/detach exports stay small so the Android app
  can own the shell.
- `moui/mobile/android` owns the canonical Kotlin `ComponentActivity`,
  `MoUISurfaceView`, PlatformView overlay/factory API, clipboard provider,
  virtual accessibility bridge, `Choreographer`, registered JNI adapter,
  `ANativeWindow` acquisition, and reusable CMake wiring.
- `examples/counter/android_app` and
  `examples/component_gallery/android_app` own only app Gradle metadata,
  manifest/resources, and their thin CMake include.
- `moui/mobile/legacy/android` preserves the Release N Java shell and
  name-mangled JNI adapter as a one-release compatibility fixture. It is never
  selected implicitly.

Android stays on minSdk 23 and targetSdk 35. The managed shell compiles against
SDK 36 because AndroidX Activity 1.13.0 declares `minCompileSdk=36`; disabling
the AAR metadata check is not supported. Product `auto` prefers Vulkan on API 24+ with GLES
fallback (and GLES on API 23) when the host GPU surface is available.
`SkiaRasterNative` remains the explicit mode and sticky recovery fallback and
still copies full pixel frames on that path.

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

- Android SDK Platform 36 (compile SDK required by AndroidX Activity 1.13.0)
- Android SDK Build-Tools 35.0.0
- Android SDK Platform-Tools
- **NDK 28.2.13676358** (pinned by `moui/mobile/android/mobile-app.gradle` and
  `moui/scripts/mobile/prepare-native-build.mjs`; override only with care)
- CMake 3.22.1
- For emulator smoke: `emulator` package + a system image matching host arch

Example command-line setup:

```sh
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"   # macOS default
# Linux default is often ~/Android/Sdk
mkdir -p "$ANDROID_HOME/cmdline-tools"
# Unzip the official commandlinetools package so that this path exists:
#   "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmake/3.22.1/bin:$PATH"

sdkmanager --licenses
sdkmanager --install \
  "platform-tools" \
  "platforms;android-36" \
  "build-tools;35.0.0" \
  "cmake;3.22.1" \
  "ndk;28.2.13676358"
```

Pin the same NDK everywhere (Gradle `ndkVersion`, prepare script, and
`ANDROID_NDK_HOME`):

```sh
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/28.2.13676358"
```

**libc++ packaging:** MoUI packages the full NDK `libc++_shared.so` (`c++_shared`
STL, `doNotStrip`). Mixing NDK A to compile with NDK B / a stripped minimal
libc++ causes `UnsatisfiedLinkError` on `std::ostringstream` at `dlopen` and
empty runtime streams. If native fails to load, reinstall NDK 28.2, clean
`.cxx` / jniLibs / Gradle caches, and rebuild.

## Mobile APK Builds

Android APK builds now use the shared mobile Gradle route. The app-specific
shells under `examples/counter/android_app` and
`examples/component_gallery/android_app` consume app-facing metadata from
`examples/<app>/mobile.json` plus package-published compatibility contracts
from `moui/mobile/build-contracts.json`. The reusable Gradle script, Kotlin
`ComponentActivity`, registered JNI bridge, CMake module, and copyable project
template live under `moui/mobile`
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

Renderer mode is explicit and auditable:

```sh
scripts/build-mobile-android-apk.sh --app counter --renderer auto
scripts/build-mobile-android-apk.sh --app counter --renderer skia-raster
```

For real Skia packages, `auto` and `skia-gpu` select GPU (`gpuPromoted: true`).
Fallback-Skia builds and explicit `skia-raster` stay on the CPU presenter.

When multiple side-by-side NDK versions are installed, pin **28.2.13676358**:

```sh
ANDROID_HOME=/path/to/Android/Sdk \
ANDROID_NDK_HOME=/path/to/Android/Sdk/ndk/28.2.13676358 \
scripts/build-mobile-android-apk.sh --app counter
```

The default APK path resolves the locked Android Skia provider through
`moui_skia/build.js`, uses the dynamic Android Skia artifact so native
dependencies can be packaged, builds the app's native library, packages the
shared Kotlin `SurfaceView`/PlatformView-overlay glue, and writes:

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
Kotlin/resource packaging, and debug signing. It reports native Skia unavailable
and must not be used as first-frame runtime evidence.

The old app-specific build scripts remain compatibility wrappers over
`scripts/build-mobile-android-apk.sh --app ...`.

The default build always selects the managed shell. During the Release N
compatibility window, maintainers can build the frozen Java fixture explicitly:

```sh
scripts/build-mobile-android-apk.sh \
  --app counter \
  --fallback-skia \
  --legacy-java-shell \
  --compile-sdk 35
```

This flag switches the Java/Kotlin source root, manifest Activity/provider,
and CMake JNI glue root as one unit. It is a compatibility audit, not a second
production mode.

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

## Emulator Setup And Smoke

Three evidence layers stay separate: **product GPU default** (source/`auto`),
**mobile runtime smoke (L2)**, and **seven-gate GPU promotion claim (L3)**.

| Layer | Meaning | Android bar for “GPU feasible” |
| --- | --- | --- |
| L1 packaging | Non-fallback APK, `selected=skia-gpu`, `gpuPromoted=true` | Required |
| L2 runtime | Process loads native + configure log: `skia-gpu-native`, `vulkan-gpu` or `egl-gpu`, **`gpuAvailable=true`**, attach + nonblank frame | **Required** |
| L3 seven-gate claim | 600s perf/memory/context-loss, `claimed=true` | **Not required** for feasibility |

`scripts/setup-android-sdk.sh` installs platform-tools, platforms, build-tools,
CMake, and NDK — **not** the emulator or system images. Install those next.

### Install emulator + system image + AVD

Host arch: Apple Silicon / arm64 hosts use `arm64-v8a` images; x86_64 hosts use
`x86_64`.

```sh
scripts/setup-android-sdk.sh --accept-licenses --ndk 28.2.13676358
eval "$(scripts/setup-android-sdk.sh --print-env)"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/28.2.13676358}"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Emulator binary + API 34 Google APIs image (adjust API/arch as needed)
sdkmanager --install \
  "emulator" \
  "system-images;android-34;google_apis;arm64-v8a"

# Create AVD once (name is local; use any stable name)
echo no | avdmanager create avd \
  -n moui_api34 \
  -k "system-images;android-34;google_apis;arm64-v8a" \
  -d pixel_6 \
  --force

avdmanager list avd
```

### Start the emulator

```sh
# Prefer GPU host acceleration when available
emulator -avd moui_api34 -gpu host -no-snapshot-save &
# Headless CI-style alternative:
# emulator -avd moui_api34 -gpu swiftshader_indirect -no-window -no-audio -no-snapshot-save &

adb wait-for-device
adb devices -l
# Wait until boot completed
adb shell getprop sys.boot_completed   # expect 1
```

Do **not** run Android and HarmonyOS emulators at the same time on low-memory
hosts.

### Build non-fallback APK (L1)

```sh
scripts/build-mobile-android-apk.sh --app component_gallery --renderer auto
# Optional packaging checks:
# unzip -l artifacts/android/component_gallery/app-debug.apk | rg 'lib/.*/(libcomponent|libskia|libc\+\+_shared)'
# python3 -c "import os; p='…/libc++_shared.so'; print(os.path.getsize(p))"  # expect multi-MB, not ~1MB stripped
```

Artifact: `artifacts/android/component_gallery/app-debug.apk`  
Meta: `artifacts/android/component_gallery/native/mobile-build.json` →
`selected=skia-gpu`, `gpuPromoted=true`, `fallbackSkia=false`.

### Install + manual launch (without full recorder)

```sh
SERIAL="$(adb devices | awk '/\tdevice$/{print $1; exit}')"
APK=artifacts/android/component_gallery/app-debug.apk

adb -s "$SERIAL" install -r "$APK"
adb -s "$SERIAL" logcat -c
# Activity is the shared template class (not applicationId-relative).
adb -s "$SERIAL" shell am start -n \
  dev.wzzc.moui.componentgallery/dev.wzzc.moui.mobile.MoUIActivity
# If start fails: adb shell cmd package resolve-activity --brief dev.wzzc.moui.componentgallery

# Continuous GPU configure evidence (do not use one-shot logcat dumps only)
adb -s "$SERIAL" logcat -s MoUIMobile:V | tee /tmp/moui-android-cg.log
# Expected line shape:
# moui-mobile renderer configure … status={"platform":"android","selected":"skia-gpu-native",
#   "surfaceRoute":"vulkan-gpu"|"egl-gpu","gpuAvailable":true,"gpuPromoted":true,…}

# Optional screenshot
adb -s "$SERIAL" exec-out screencap -p > /tmp/moui-android-cg.png
```

If the app crashes immediately with `UnsatisfiedLinkError` / missing
`ostringstream` vtable, fix NDK/libc++ packaging (see [SDK And NDK Setup](#sdk-and-ndk-setup))
before treating GPU as unavailable.

### Record + validate smoke (L2)

```sh
SERIAL="$(adb devices | awk '/\tdevice$/{print $1; exit}')"

scripts/build-mobile-android-apk.sh --app component_gallery --renderer auto
node scripts/record-mobile-runtime-smoke.mjs \
  --platform android --app component_gallery --device "$SERIAL"
node scripts/validate-mobile-runtime-manifest.mjs \
  artifacts/mobile-runtime/android/component_gallery/mobile-runtime-smoke.json
# Full service gate only when observations are green:
# node scripts/record-mobile-runtime-smoke.mjs \
#   --platform android --app component_gallery --device "$SERIAL" --require-passed
```

Evidence directory: `artifacts/mobile-runtime/android/component_gallery/`

```sh
rg -n 'renderer configure|surfaceRoute|gpuAvailable|UnsatisfiedLinkError' \
  artifacts/mobile-runtime/android/component_gallery/runtime-stream.log \
  artifacts/mobile-runtime/android/component_gallery/runtime.log
```

**L2 GPU pass conditions:**

| Check | Expect |
| --- | --- |
| Native load | No `UnsatisfiedLinkError` |
| configure | `selected=skia-gpu-native` |
| route | `vulkan-gpu` (preferred API 24+) or `egl-gpu` |
| | **`gpuAvailable":true`** |
| Frame | nonblank first frame + attach |
| Better | IME/clipboard/a11y/async-image → `status=passed` |

Packaging-only (`gpuAvailable=false`, empty stream, fallback-Skia APK) is **not**
GPU-feasible L2.

### GPU feasibility snapshot (local, 2026-07-15)

Component Gallery smoke under `artifacts/mobile-runtime/android/component_gallery/`:

- `status`: **`passed`** (`--require-passed` ok, 2026-07-15)
- `renderer.selected`: `SkiaGpuNative`
- `surfaceRoute`: **`vulkan-gpu`**
- `gpuAvailable` / `gpuPromoted`: **true**
- Observations: attach, detach, nonblank first frame, resize, representative
  input, scroll, IME, clipboard write/read, accessibility tree/focus/action,
  async-image, clean shutdown all **yes**; `realDeviceSigning` remains pending
  on emulator. Shell-side service smoke + semantics probe plan cover Canvas
  virtual-node discovery that uiautomator cannot see.

## Runtime Evidence Required

A **full `passed`** Android runtime claim requires a non-fallback APK plus
matching device/emulator evidence for at least:

- Activity/Surface lifecycle creating and disposing an `AndroidRuntimeSession`.
- `ANativeWindow` presentation with nonblank first-frame pixels.
- Resize and pointer callbacks reaching `HostRuntimeDriver`.
- Text input/IME observations or explicit pending status.
- Clipboard, accessibility, async image, and packaging observations or explicit
  pending status.

**GPU feasibility (L1+L2)** can be claimed earlier when configure proves the GPU
route and first-frame is nonblank (see table above). L3 seven-gate claim remains
separate (`gpuPromotionEvidence.claimed=false` on normal smoke).

The checked smoke catalog contains release/manual Android mobile runtime suites.
After a non-fallback build, record and validate with:

```sh
node scripts/record-mobile-runtime-smoke.mjs --platform android --app counter --device <serial>
node scripts/record-mobile-runtime-smoke.mjs --platform android --app component_gallery --device <serial>
# release bar only when complete:
node scripts/record-mobile-runtime-smoke.mjs \
  --platform android --app component_gallery --device <serial> --require-passed
```

Component Gallery opens `Mobile Service Probe` directly. The recorder locates
its text field and action in the Android accessibility tree, injects IME text,
uses the native Copy/Cut/Paste key events, rotates and restores the device,
scrolls, and requires async-image loading/ready logs. Pass `--device
<adb-serial> --assistive-tech` for physical-device acceptance with TalkBack
already installed and enabled. A passed run requires two distinct logged
surface sizes plus accessibility tree, focus, and targeted action receipts;
ordinary coordinate taps do not substitute for TalkBack actions.

Device acceptance must still manually round-trip a PNG through another app
before image clipboard support can be promoted.
