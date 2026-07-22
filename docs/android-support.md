# Android Support

Android uses the **window-hosted** mobile route and is currently
`runtime_partial`. `wzzc-dev/window/android` owns the Android lifecycle,
surface, and input queue; `moui/backend/android` converts those callbacks into
the MoUI runtime session and `moui/backend/android/skia` provides presentation.

## Entry Points

| Piece | Location |
|---|---|
| App logic | `examples/<app>/app` |
| Mobile metadata | `examples/<app>/moui.mobile.json` |
| MoonBit entrypoint | `examples/<app>/android_window_hosted` |
| Android host template | `wzzc-dev/window/android/template` |
| MoUI adapter | `moui/backend/android/window_hosted.mbt` |

The entrypoint constructs `AndroidWindowHostedApp` and runs it through
`window/android::EventLoop`. Do not add another lifecycle, surface, or input
bridge beside the window event loop.

## Toolchain

- JDK 17 or newer (JDK 21 recommended)
- Android SDK compile API 36 and target API 35
- NDK `28.2.13676358` and CMake `3.22.1`
- Gradle `9.6.1` or compatible wrapper
- Application minimum SDK 23

Run `moui doctor --platform android` before a native build.

## Build And Run

From the repository root:

```sh
moon check examples/showcase/android_window_hosted --target native
moui build android showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
moui run android showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json"
```

Use `--prepare-only` to inspect generated native inputs without invoking
Gradle. `--fallback-skia` verifies packaging only; it does not establish
renderer or runtime support.

## Validation And Evidence

Host-sim validation does not require an emulator:

```sh
sh scripts/window-hosted-hostsim-smoke.sh
moon test moui/backend/android --target native
```

For a runtime claim, use a matching device or emulator and record first frame,
input, surface detach/recreate, IME, clipboard, accessibility, and async-image
observations. Keep `checks/platforms/android.json` at `partial` until that
evidence verifies the actual presenter route.

## Status

The route is usable for development and template integration, but it is not a
product-complete Android claim. See `docs/platform-readiness-declaration.md`
and `docs/window-hosted-moui.md` for the evidence boundary.
