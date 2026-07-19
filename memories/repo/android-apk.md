# Android APK Route

- Android remains an experimental embedded-session route: `moui/backend/android`
  owns the session/host contract and `moui/backend/android/skia` owns
  `ANativeWindow` Skia presentation.
- `examples/counter/android_skia` installs the Counter runtime and renderer;
  its root export shims forward mechanically to the framework-owned Embedding
  API implementation. JNI calls the negotiated Embedding API table rather than
  reaching into runtime internals.
- The Counter APK shell is staged from `moui_shell/android`. Use
  `scripts/build-counter-android-apk.sh` for the real Android Skia path. The
  default path uses dynamic Android Skia and packages `libskia.so` plus the NDK
  `libc++_shared.so` beside `libmoui_counter_android.so`.
- Use `scripts/build-counter-android-apk.sh --fallback-skia` only for
  packaging, JNI, CMake, and signing smoke.
- Fallback APKs are not renderer/runtime evidence. Android support is not
  passed until a matching device or emulator smoke records nonblank first frame,
  pointer/input, and lifecycle observations.
