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
- `examples/counter/android_skia` is a thin Counter entrypoint for future
  JNI/CMake/Gradle wiring. Its attach/resize/render/detach functions are small
  so an Android app can own the Activity shell.

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

## Runtime Evidence

The Android route is not release-ready runtime evidence. A passed claim still
needs a matching Android device or emulator smoke that proves at least:

- Activity/Surface lifecycle creates and disposes an `AndroidRuntimeSession`.
- `ANativeWindow` presentation shows a nonblank first frame.
- Resize and input callbacks reach `HostRuntimeDriver`.
- Text input/IME, clipboard, accessibility, async image, and packaging gaps are
  either implemented or explicitly recorded as pending.

Until those observations exist, Android should be described as an experimental
scaffold, not as a passed platform.
