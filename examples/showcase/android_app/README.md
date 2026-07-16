# MoUI Showcase Android

This is the app-owned Gradle project for the experimental MoUI Showcase
Android route. The shared mobile Android template owns the Kotlin/AndroidX
managed `Activity`, registered JNI bridge, `ANativeWindow` handling,
PlatformView overlay, and CMake source list; this project supplies app
metadata from `examples/showcase/mobile.json`. MoUI Showcase's
repository compatibility native symbol and MoonBit C details live in
`moui/mobile/build-contracts.json`.

Install the Android SDK/NDK with the repository helper, Android Studio's SDK
Manager, or the official command-line `sdkmanager`; see
`docs/android-support.md#android-sdk-and-ndk`. The build expects `ANDROID_HOME`
or `ANDROID_SDK_ROOT` to point at that SDK root. `ANDROID_NDK_HOME` is optional
when a side-by-side NDK is installed under `$ANDROID_HOME/ndk`. A JDK must also
be available on `PATH` for `java`, `javac`, `jlink`, and `keytool`.

Build from the repository root:

```sh
scripts/setup-android-sdk.sh --accept-licenses
eval "$(scripts/setup-android-sdk.sh --print-env)"
scripts/build-mobile-android-apk.sh --app showcase
```

If the SDK is already installed elsewhere:

```sh
ANDROID_HOME=/path/to/Android/Sdk \
scripts/build-showcase-android-apk.sh
```

The script generates MoonBit C into an ignored build directory, resolves the
locked Android Skia provider, then runs this Gradle project to compile the
native library and package the debug APK:

```text
artifacts/android/showcase/app-debug.apk
```

The APK is build evidence only. Runtime support is still experimental until a
matching Android device or emulator smoke records first-frame, input, and
lifecycle observations.

Use `scripts/build-showcase-android-apk.sh --fallback-skia` only for a fast
packaging/JNI/CMake smoke; that APK reports Skia unavailable.

The Java shell under `moui/mobile/legacy/android` is only the Release N
compatibility fixture and must be selected explicitly with
`--legacy-java-shell --compile-sdk 35`.
