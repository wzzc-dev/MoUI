# MoUI Counter Android

This is the app-owned Gradle project for the experimental Counter Android
route. The shared mobile Android template owns the Java `Activity`, JNI,
`ANativeWindow` handling, and CMake source list; this project supplies app
metadata from `examples/counter/mobile.json`. Counter's repository
compatibility native symbol and MoonBit C details live in
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
scripts/build-mobile-android-apk.sh --app counter
```

If the SDK is already installed elsewhere:

```sh
ANDROID_HOME=/path/to/Android/Sdk \
scripts/build-counter-android-apk.sh
```

The script generates MoonBit C into an ignored build directory, resolves the
locked Android Skia provider, then runs this Gradle project to compile the
native library and package the debug APK:

```text
artifacts/android/counter/app-debug.apk
```

The APK is build evidence only. Runtime support is still experimental until a
matching Android device or emulator smoke records first-frame, input, and
lifecycle observations.

Use `scripts/build-counter-android-apk.sh --fallback-skia` only for a fast
packaging/JNI/CMake smoke; that APK reports Skia unavailable.
