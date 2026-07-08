# Android APK Route

- Android remains an experimental embedded-session route: `moui/backend/android`
  owns the session/host contract and `moui/backend/android/skia` owns
  `ANativeWindow` Skia presentation.
- `examples/counter/android_skia` exports C ABI functions for attach, resize,
  pointer dispatch, render, and detach. JNI should call those exports rather
  than reaching into runtime internals.
- `examples/counter/android_app` is the current Counter APK shell. Use
  `scripts/build-counter-android-apk.sh` for the real Android Skia path. The
  default path uses dynamic Android Skia and packages `libskia.so` plus the NDK
  `libc++_shared.so` beside `libmoui_counter_android.so`.
- Use `scripts/build-counter-android-apk.sh --fallback-skia` only for
  packaging, JNI, CMake, and signing smoke.
- Fallback APKs are not renderer/runtime evidence. Android support is not
  passed until a matching device or emulator smoke records nonblank first frame,
  pointer/input, and lifecycle observations.
