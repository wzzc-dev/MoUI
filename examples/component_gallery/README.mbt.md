# Component Gallery

Component Gallery is MoUI's reusable component story browser. It is organized
around grouped stories for common `moui/views` controls, with one shared
model/update/view app running on macOS, Linux, Windows, Android, iOS, and Web.

This example intentionally uses plain entrypoint names:

- `macos`, `linux`, and `windows` are the default native Skia routes.
- `android` and `ios` are experimental embedded-session Skia routes.
- `web` is the Web wasm-gc route.

The directories do not use `_skia` or `web_wasm` here because Skia and Web are
the default routes for this gallery. Future non-default renderer routes should
spell out the renderer, such as `macos_wgpu`.

## Package Shape

- `app/` - shared app logic split by responsibility:
  - `model.mbt` owns `PlatformId`, story selection, component sample state, and
    the TEA `update`.
  - `stories.mbt` owns story ids, groups, metadata, and search helpers.
  - `platforms.mbt` owns six-host route metadata and commands.
  - `view.mbt` owns the responsive story browser shell.
  - `story_views.mbt` owns reusable component story content.
  - `app.mbt` stays as the thin `program(active_platform~)` facade.
- `macos/`, `linux/`, `windows/` - thin desktop entrypoints. Each creates a
  1040x720 runtime titled "Component Gallery" and calls the matching Skia
  backend.
- `web/` - Web wasm-gc entrypoint plus `index.html` bootstrap.
- `android/` - native embedded-session exports for surface attach, resize,
  pointer dispatch, render, and detach.
- `android_app/` - app-owned Android Activity/JNI/CMake shell that loads
  `component_gallery_android`.
- `ios/` - native embedded-session exports for UIKit view attach, resize,
  pointer dispatch, render, and detach.
- `ios_app/` - app-owned UIKit shell. Its bundle id is
  `dev.wzzc.moui.componentgallery`.

## Running Desktop

From the repository root:

```sh
moon run examples/component_gallery/macos --target native
moon run examples/component_gallery/linux --target native
moon run examples/component_gallery/windows --target native
```

The desktop routes require the same native Skia setup as the platform backend
providers.

## Running Web

```sh
moon build examples/component_gallery/web --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:8080/examples/component_gallery/web/
```

## Android Packaging

```sh
scripts/build-component-gallery-android-apk.sh
```

For a packaging-only smoke that does not fetch or link real Skia:

```sh
scripts/build-component-gallery-android-apk.sh --fallback-skia
```

The default output is:

```text
artifacts/android/component_gallery/app-debug.apk
```

Fallback APKs are packaging evidence only. Real Android runtime support still
requires a non-fallback build plus matching device/emulator first-frame, input,
and lifecycle smoke evidence.

## iOS Packaging

```sh
scripts/build-component-gallery-ios-app.sh
```

For a packaging-only smoke that does not fetch or link real Skia:

```sh
scripts/build-component-gallery-ios-app.sh --fallback-skia
```

The default output is:

```text
artifacts/ios/component_gallery/ComponentGallery.app
```

Install and launch on a booted simulator:

```sh
xcrun simctl install booted artifacts/ios/component_gallery/ComponentGallery.app
xcrun simctl launch booted dev.wzzc.moui.componentgallery
```

Fallback `.app` bundles are packaging evidence only. Real iOS runtime support
still requires a non-fallback build plus matching simulator/device first-frame,
input, and lifecycle smoke evidence.

## Focused Checks

```sh
moon test examples/component_gallery/app --target native
moon check examples/component_gallery/macos --target native
moon check examples/component_gallery/windows --target native
moon check examples/component_gallery/linux --target native
moon build examples/component_gallery/web --target wasm-gc
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/component_gallery/android --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/component_gallery/ios --target native
bash -n scripts/build-component-gallery-android-apk.sh
bash -n scripts/build-component-gallery-ios-app.sh
```

See `docs/examples.md` for the cross-example command catalog and evidence
policy.
