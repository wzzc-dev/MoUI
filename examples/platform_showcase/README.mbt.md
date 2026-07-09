# Platform Showcase

Platform Showcase is MoUI's six-platform app showcase. It is intentionally more
product-like than the framework catalog in `examples/showcase`: one shared
model/update/view app renders a release-console surface on macOS, Linux,
Windows, Android, iOS, and Web.

This example intentionally uses plain entrypoint names:

- `macos`, `linux`, and `windows` are the default native Skia routes.
- `android` and `ios` are experimental embedded-session Skia routes.
- `web` is the Web wasm-gc route.

The directories do not use `_skia` or `web_wasm` here because Skia and Web are
the default routes for this showcase. Future non-default renderer routes should
spell out the renderer, such as `macos_wgpu`.

## Package Shape

- `app/` - shared app logic. `PlatformShowcaseModel` stores the active platform,
  selected runtime route, release note text, segmented/picker choices, mobile
  shell toggle, readiness slider, and demo counter state.
  `program(active_platform~)` builds the reusable MoUI program.
- `macos/`, `linux/`, `windows/` - thin desktop entrypoints. Each creates a
  1040x720 runtime titled "MoUI Platform Showcase" and calls the matching Skia
  backend.
- `web/` - Web wasm-gc entrypoint plus `index.html` bootstrap.
- `android/` - native embedded-session exports for surface attach, resize,
  pointer dispatch, render, and detach.
- `android_app/` - app-owned Android Activity/JNI/CMake shell that loads
  `platform_showcase_android`.
- `ios/` - native embedded-session exports for UIKit view attach, resize,
  pointer dispatch, render, and detach.
- `ios_app/` - app-owned UIKit shell. Its bundle id is
  `dev.wzzc.moui.platformshowcase`.

## Running Desktop

From the repository root:

```sh
moon run examples/platform_showcase/macos --target native
moon run examples/platform_showcase/linux --target native
moon run examples/platform_showcase/windows --target native
```

The desktop routes require the same native Skia setup as the platform backend
providers.

## Running Web

```sh
moon build examples/platform_showcase/web --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:8080/examples/platform_showcase/web/
```

## Android Packaging

```sh
scripts/build-platform-showcase-android-apk.sh
```

For a packaging-only smoke that does not fetch or link real Skia:

```sh
scripts/build-platform-showcase-android-apk.sh --fallback-skia
```

The default output is:

```text
artifacts/android/platform_showcase/app-debug.apk
```

Fallback APKs are packaging evidence only. Real Android runtime support still
requires a non-fallback build plus matching device/emulator first-frame, input,
and lifecycle smoke evidence.

## iOS Packaging

```sh
scripts/build-platform-showcase-ios-app.sh
```

For a packaging-only smoke that does not fetch or link real Skia:

```sh
scripts/build-platform-showcase-ios-app.sh --fallback-skia
```

The default output is:

```text
artifacts/ios/platform_showcase/MoUIPlatformShowcase.app
```

Install and launch on a booted simulator:

```sh
xcrun simctl install booted artifacts/ios/platform_showcase/MoUIPlatformShowcase.app
xcrun simctl launch booted dev.wzzc.moui.platformshowcase
```

Fallback `.app` bundles are packaging evidence only. Real iOS runtime support
still requires a non-fallback build plus matching simulator/device first-frame,
input, and lifecycle smoke evidence.

## Focused Checks

```sh
moon test examples/platform_showcase/app --target native
moon check examples/platform_showcase/macos --target native
moon check examples/platform_showcase/windows --target native
moon check examples/platform_showcase/linux --target native
moon build examples/platform_showcase/web --target wasm-gc
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/platform_showcase/android --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/platform_showcase/ios --target native
bash -n scripts/build-platform-showcase-android-apk.sh
bash -n scripts/build-platform-showcase-ios-app.sh
```

See `docs/examples.md` for the cross-example command catalog and evidence
policy.
