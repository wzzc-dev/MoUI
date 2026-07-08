# Android Support

Android support is currently an experimental embedded native scaffold. It is
modeled after the desktop Skia split, with one important difference: MoUI does
not own the Android Activity or event loop yet. The Android layer supplies a
native surface handle and forwards lifecycle, input, resize, and redraw
callbacks into MoUI.

## Packages

- `moui/backend/android` owns the Android host contract:
  `AndroidSurfaceHandle`, `AndroidRendererProvider`, capability/readiness
  summaries, and `AndroidRuntimeSession`.
- `moui/backend/android/skia` owns the Android Skia provider. It wraps
  `moui/render/skia` in a `HostWindowRenderer` and presents RGBA frames to an
  `ANativeWindow` when compiled on Android.
- `examples/counter/android_skia` is a thin Counter MoonBit entrypoint for
  JNI/CMake wiring. Its exported attach/resize/pointer/render/detach functions
  are small so an Android app can own the Activity shell.
- `examples/counter/android_app` is the experimental Counter APK shell. The
  Java `Activity` owns `SurfaceView` lifecycle and touch forwarding, JNI owns
  `ANativeWindow` acquisition, and CMake compiles the MoonBit-generated C,
  MoonBit runtime, Android presenter, and `moui_skia/native` stubs into one
  Android shared library.

## Skia Prebuild

Use explicit Skia prebuild variables when cross-building the native route:

```sh
MOUI_SKIA_PLATFORM=android \
MOUI_SKIA_ARCH=arm64 \
MOUI_SKIA_LINK_MODE=static \
moon check examples/counter/android_skia --target native
```

`MOUI_SKIA_PLATFORM=android` selects the Android asset from
`moui_skia/skia-provider-lock.json` instead of inferring the desktop host
platform. `MOUI_SKIA_ARCH` accepts `arm64`, `x64`, or `riscv64`, matching the
locked provider manifest. As with desktop Skia, `MOUI_SKIA_SKIA_INCLUDE` and
`MOUI_SKIA_SKIA_LIB_DIR` may override the release provider when an Android
build system has already staged Skia.

## Android SDK And NDK

MoUI does not require a repository-private Android SDK location. Install the
SDK/NDK with the official Android tools, then point `ANDROID_HOME` at the SDK
root that Android Studio, `sdkmanager`, or the repository helper created. Do
not document machine-local SDK paths as project requirements.

Official setup options:

- Repository helper: install the official command-line tools and required SDK
  packages in one step. This requires a JDK on `PATH` because Google's
  `sdkmanager` runs on Java and the APK builder later uses `javac` and
  `keytool`:

```sh
scripts/setup-android-sdk.sh --accept-licenses
eval "$(scripts/setup-android-sdk.sh --print-env)"
```

  By default this installs under `~/Library/Android/sdk` on macOS and
  `~/Android/Sdk` on Linux. Use
  `scripts/setup-android-sdk.sh --android-home /path/to/Android/Sdk` when you
  need a different SDK root.
- Android Studio: install Android Studio from
  <https://developer.android.com/studio>, open SDK Manager, and install Android
  SDK Platform 35, Android SDK Build-Tools 35.0.0, Android SDK Platform-Tools,
  NDK (Side by side), and CMake 3.22.1.
- Manual command line / CI: download the official "Command line tools only" package
  from <https://developer.android.com/studio#command-line-tools-only>, stage it
  as `$ANDROID_HOME/cmdline-tools/latest`, then use `sdkmanager`:

```sh
export ANDROID_HOME="$HOME/Android/Sdk"
mkdir -p "$ANDROID_HOME/cmdline-tools"
# Unzip the official commandlinetools package so that this directory exists:
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

The APK script reads `ANDROID_HOME` or `ANDROID_SDK_ROOT`. If the NDK was
installed under `$ANDROID_HOME/ndk`, the script auto-selects the latest NDK
directory; set `ANDROID_NDK_HOME="$ANDROID_HOME/ndk/25.2.9519653"` only when
you need to pin a specific NDK. When `ANDROID_HOME` is not set, the APK script
also checks the common SDK roots `~/Library/Android/sdk` and `~/Android/Sdk`.
The direct APK builder also needs `javac`, `keytool`, and `cmake` on `PATH`;
install a JDK first if `java`, `javac`, or `keytool` are missing.

## Counter APK

Build the experimental Counter debug APK from the repository root:

```sh
ANDROID_HOME=/path/to/Android/Sdk \
scripts/build-counter-android-apk.sh
```

When multiple side-by-side NDK versions are installed, pin the intended one:

```sh
ANDROID_HOME=/path/to/Android/Sdk \
ANDROID_NDK_HOME=/path/to/Android/Sdk/ndk/25.2.9519653 \
scripts/build-counter-android-apk.sh
```

The script follows the same native-stub pattern as the Android path in
`moonbit-community/tonyfettes-raylib`: MoonBit emits native C, the Android build
passes platform-specific C/C++ and link flags into CMake, and the NDK links the
generated MoonBit code with the native stubs. MoUI adds an APK shell on top of
that pattern because Android needs an Activity/JNI owner for the `Surface`.

By default the script resolves the locked Android Skia provider through
`moui_skia/build.js`, uses the dynamic Android Skia artifact so APK native
dependencies can be packaged, builds `libmoui_counter_android.so`, packages
Java `SurfaceView` glue, and writes:

```text
artifacts/android/counter/app-debug.apk
```

The debug APK includes `lib/arm64-v8a/libmoui_counter_android.so`,
`lib/arm64-v8a/libskia.so`, and the NDK `libc++_shared.so` for the default
`arm64-v8a` ABI. Set `MOUI_SKIA_LINK_MODE=static` only for explicit static-link
experiments; the default APK path uses dynamic Skia because it matches Android
native library packaging.

Use this fast smoke when you only need to validate MoonBit C generation, JNI,
CMake, Java/resource packaging, and debug signing without downloading or
linking real Skia:

```sh
scripts/build-counter-android-apk.sh --fallback-skia
```

`--fallback-skia` can produce an APK, but that APK is packaging evidence only:
the native Skia renderer reports unavailable and it should not be used as
first-frame runtime evidence.

## Runtime Evidence

The Android route is not release-ready runtime evidence. A passed claim still
needs a matching Android device or emulator smoke that proves at least:

- Activity/Surface lifecycle creates and disposes an `AndroidRuntimeSession`.
- `ANativeWindow` presentation shows a nonblank first frame.
- Resize and pointer callbacks reach `HostRuntimeDriver`.
- Text input/IME, clipboard, accessibility, async image, and packaging gaps are
  either implemented or explicitly recorded as pending.

Until those observations exist, Android should be described as an experimental
scaffold, not as a passed platform.
