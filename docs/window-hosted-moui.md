# Embedded Runtime Backends

Android, iOS, and HarmonyOS use the **embedded runtime backend** model. Their
`wzzc-dev/window` embedder is the winit-style host:
`HostCmd` → `EventLoop` → `ApplicationHandler`. Surface and input do not go
through a second attach/inject bridge.

This is an ownership classification, not a device classification. Android and
HarmonyOS desktop products still use the embedded runtime backend model when
their platform embedder owns the lifecycle, surface, input, and event loop.

## Architecture

```text
window/<platform>/template / native Activity|UIApp|Ability
        → window HostCmd queue
        → EventLoop.pump / run_app
        → *EmbeddedRuntimeBackend (moui/backend/{android,ios,harmonyos})
        → AndroidRuntimeSession / IosRuntimeSession / HarmonyOsRuntimeSession
        → Skia HostWindowRenderer
```

The window-hosted route is the only supported embedded runtime backend path.
Do not add a second lifecycle, surface, or input bridge beside `HostCmd` and
`ApplicationHandler`.

## Packages

| Piece | Path |
|-------|------|
| Android embedded runtime backend | `moui/backend/android/window_hosted.mbt` (`AndroidEmbeddedRuntimeBackend`) |
| iOS embedded runtime backend | `moui/backend/ios/window_hosted.mbt` (`IosEmbeddedRuntimeBackend`) |
| HarmonyOS embedded runtime backend | `moui/backend/harmonyos/window_hosted.mbt` (`HarmonyOsEmbeddedRuntimeBackend`) |
| Counter entries | `examples/counter/{android,ios,harmonyos}_window_hosted` |
| window contract | `window/docs/mobile-hosted-backend.md` |
| mobile status | `checks/platforms/{android,ios,harmonyos}.json` |

## Validation

Host-sim (no emulator required):

```sh
sh scripts/window-hosted-hostsim-smoke.sh
```

VM facade (host-sim + optional device probes):

```sh
# always runs host-sim
sh scripts/window-hosted-vm-smoke.sh

# when AVD/Simulator/HVD ready:
WINDOW_HOSTED_ANDROID_AVD=1 sh scripts/window-hosted-vm-smoke.sh
WINDOW_HOSTED_IOS_SIM=1 sh scripts/window-hosted-vm-smoke.sh
WINDOW_HOSTED_HARMONYOS_HVD=1 sh scripts/window-hosted-vm-smoke.sh
```

Window package only:

```sh
moon test window/modules/window/android --target native
moon test window/modules/window/ios --target native
moon test window/modules/window/harmonyos --target native
```

## Status

| Gate | Status |
|------|--------|
| HostCmd host-sim (window) | scripts fixed; package tests pass |
| MoUI window-hosted host-sim | backend tests pass (2026-07-21) |
| Counter package check | android/ios/harmonyos_window_hosted check pass |
| Android AVD install + launch | **passed** 2026-07-21 (`moui_api34`, package `dev.wzzc.window.hosted.counter`; native lib + EventLoop started; screenshot under `artifacts/window-hosted-android/`) |
| iOS Simulator install + launch | **passed** 2026-07-21 after the UIKit host moved into `window/modules/window/ios/template/Sources` (iPhone 17 sim; `WindowHostedCounter.app`) |
| HarmonyOS HAP build | **passed** 2026-07-21: package-local Stage/XComponent/NAPI template builds `WindowHostedCounter.hap` (unsigned) |
| HarmonyOS HVD | no target online (`hdc` empty); no device-runtime claim |
| Showcase Android APK real Skia | **fixed** 2026-07-21: CMake plain/PRIVATE mix + CXX-only Skia flags; `moonbit_skia_available` returns 1 in `artifacts/android/showcase.apk` |
| Showcase HarmonyOS HAP real Skia | **fixed** 2026-07-21: `build_harmonyos` resolves Skia rsp into CMake; `moonbit_skia_available` returns 1 in `artifacts/harmonyos/showcase.hap` |

### Black screen checklist (Android / HarmonyOS)

If the app launches but the surface stays black while iOS shows UI:

1. Inspect the packaged `.so`: `objdump -d libwindow_*.so | grep -A2 moonbit_skia_available`.
   - `mov w0, wzr` (return 0) → stub Skia only; rebuild without `--fallback-skia` and ensure CMake applied rsp flags.
   - `mov w0, #0x1` → real Skia linked; then check HostCmd surface attach / present logs.
2. Android CMake must use **keyword** `target_link_libraries(... PRIVATE ...)` consistently so Skia link flags are not rejected.
3. Skia compile rsp (`-std=c++17`, `-DMOUI_SKIA_HAS_SKIA`, …) must apply to **CXX only** (`$<$<COMPILE_LANGUAGE:CXX>:...>`), not C sources.
4. HarmonyOS must not force `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` on the real path; pass `MBW_SKIA_CXX_RSP` / `MBW_SKIA_LINK_RSP` into CMake.

## Non-goals

- Claiming unverified IME, clipboard, accessibility, or platform-view support
- Claiming product_class promotion without matching-host screenshots


## Packaging (window templates only)

```sh
export JAVA_HOME="$(/usr/libexec/java_home -v 25 2>/dev/null || /usr/libexec/java_home -v 17)"
export MOONBIT_NEW_NATIVE=0
export MOUI_SKIA_DISABLE_PREBUILD_SKIA=1
bash scripts/build-window-hosted-android-apk.sh
# optional AVD: start moui_api34 with ANDROID_SDK_ROOT pointing at system-images host
adb install -r artifacts/window-hosted-android/app-debug.apk
adb shell am start -n dev.wzzc.window.hosted.counter/dev.wzzc.window.template.HostedActivity

bash scripts/build-window-hosted-ios-sim-app.sh

export HARMONYOS_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
bash scripts/build-window-hosted-harmonyos-hap.sh
```
