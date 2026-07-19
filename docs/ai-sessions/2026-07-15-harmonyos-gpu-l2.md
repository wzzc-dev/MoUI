# 2026-07-15 HarmonyOS GPU L2 feasibility

## Goal

Prove HarmonyOS GPU is runtime-feasible (L1 packaging + L2 configure route)
before resuming Android emulator work (memory: do not run both VMs together).

## Fixes landed

1. **EGL headers gate** (`moui_skia/native/skia_stub_surface_image_data.cpp`):
   HarmonyOS Skia package omits `GrGLBackendContext.h`. Opt-in
   `MOUI_SKIA_ENABLE_GPU_EGL` now defines `MOUI_SKIA_HAS_GANESH_EGL_HEADERS`
   and includes `GrGLDirectContext` / `GrGLInterface` / `GrGLBackendSurface` /
   `GrGLMakeEGLInterface`. Previously `egl_runtime_available` compiled as
   constant `return 0` → product `auto` always raster.
2. **CMake** (`moui_shell/harmonyos/cmake/MoUIShellHarmonyOS.cmake`):
   explicit `__OHOS__=1` on the mobile library.
3. **Screenshot** (`scripts/record-mobile-runtime-smoke.mjs`):
   `snapshot_display` requires `.jpeg`; recorder recv + `sips` → PNG.

## Evidence

| Item | Path / value |
| --- | --- |
| HAP + L1 meta | `artifacts/harmonyos/component_gallery/` — `selected=skia-gpu`, `gpuPromoted=true` |
| Smoke | `artifacts/mobile-runtime/harmonyos/component_gallery/mobile-runtime-smoke.json` |
| Status | **`partial`** |
| Renderer | `SkiaGpuNative` / **`egl-gpu`** / **`gpuAvailable=true`** |
| Host | DevEco MateBook Pro HVD, `hdc` `127.0.0.1:5557` |

### Command

```sh
export HARMONYOS_SDK_HOME=.../openharmony
export PATH="$HARMONYOS_SDK_HOME/toolchains:$PATH"
scripts/build-mobile-harmonyos-hap.sh --app component_gallery --renderer auto
node scripts/record-mobile-runtime-smoke.mjs \
  --platform harmonyos --app component_gallery --device 127.0.0.1:5557
```

### Marker

```text
moui-mobile renderer configure ... selected":"skia-gpu-native","surfaceRoute":"egl-gpu","gpuAvailable":true
```

## Still open for full `passed`

detach, resize, input/scroll pixel proof, clipboard, a11y focus/action,
async-image ready, realDeviceSigning.

## Android note

libc++ NDK28 packaging fixed earlier; L2 configure on emulator already shown
once (`vulkan-gpu` + `gpuAvailable=true`). Full Android smoke after HarmonyOS
session; avoid concurrent emulators.
