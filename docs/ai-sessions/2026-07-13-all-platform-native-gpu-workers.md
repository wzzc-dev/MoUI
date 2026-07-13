# 2026-07-13: All-Platform Native GPU Workers

- **Agent**: Codex
- **Goal**: Implement the ADR 0006 all-platform GPU plan for macOS, Windows,
  Linux, Android, iOS, HarmonyOS, and Web while retaining raster fallback.
- **Outcome**: Partial by promotion criteria. Shared architecture and all
  native backend source paths are implemented and local gates pass; real
  matching-hardware promotion evidence is still required.

## Summary

Added immutable `SkPicture` recording and a dedicated native GPU worker with a
latest-wins frame slot, ordered lifecycle controls, completion polling,
generation checks, device-loss recovery, and automatic raster fallback. Native
providers now target Metal, D3D12, Wayland/Android Vulkan, or EGL/GLES; WebGPU
recreates its device and canvas state after loss and falls back to Canvas2D
after two failed recovery attempts.

The final integration pass separated queued work from actual presentation.
Hosts count and track only `Presented`, poll pending desktop frames without
resubmission, drain mobile completions every VSync, preserve `AppRuntime` on
fallback, and record cached layers plus platform-view pixels into pictures so
raster replay remains complete.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `moui_skia/native` | Added Picture/recorder bindings, C++ GPU worker, Metal/D3D12/Vulkan/EGL platform branches, diagnostics, recovery, and ownership tests | Keep MoonBit GC objects off the worker and give GPU resources one thread owner |
| `moui/render` and `moui/render/skia` | Added unified native selection, completion types, mock worker, hybrid fallback, nested-picture cache, and platform-view recording | Share contracts and preserve complete raster fallback |
| `moui/backend/host` and native backends | Added completion polling, pending-frame scheduling, Presented-only accounting, surface generation handling, and mobile VSync drains | Make first-frame and image tracking reflect a real present |
| `moui/backend/web/runtime.js` | Added `GPUDevice.lost` recovery, stable import handles, diagnostics, and two-failure Canvas2D fallback | Match native recovery/fallback behavior without a native worker |
| Mobile templates and examples | Added `renderer_configure`, renderer status, and `auto\|skia-gpu\|skia-raster` wiring | Remove hard-coded raster selection and make validation explicit |
| Promotion validators/docs | Added all-platform manifest validation, zero-readback guard, D3D12 consistency, and pending promotion tables | Prevent source/build evidence from being mistaken for promotion |

## Key Decisions

- MoonBit runtime/GC values never cross the renderer thread boundary; only a
  native retained picture and POD frame metadata are queued.
- `PictureRecorded` and `queued=true` are not presentation. Only `Presented`
  advances first-frame state, image revision tracking, or present counts.
- Raster stays permanent. After terminal GPU recovery failure, the renderer
  changes while the runtime, window, input state, and app model remain alive.
- All `gpu_promoted` flags remain `false` until the seven ADR 0006 gates pass
  on matching hardware with provenance.

## Validation

```sh
moon test moui/render/skia --target native          # 108/108
moon test moui/backend/host --target native         # 105/105
moon test moui_skia --target native                 # 75/75
moon check --target native                          # passed
sh scripts/check.sh --profile daily                 # passed
sh scripts/check.sh --profile platform              # passed
node scripts/validate-gpu-worker-no-readback.mjs    # passed
scripts/macos-skia-renderer-smoke.sh --run-gpu-smoke --run-showcase-smoke
                                                    # worker-owned Metal first frame passed
NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost \
  sh scripts/ci-web-runtime-presentation.sh          # Chrome WebGPU presentation passed
scripts/build-counter-ios-app.sh --renderer skia-gpu
scripts/build-counter-android-apk.sh --renderer skia-gpu
moui/scripts/mobile/build-harmonyos-hap.sh --app harmonyos_demo \
  --harmonyos-project examples/harmonyos_demo/harmonyos_app \
  --renderer skia-gpu                               # all three builds passed
```

When the repository proxy variables are set, the Web smoke must bypass the
proxy for localhost; otherwise its readiness curl cannot observe the local
Python server even though the server started successfully.

## Follow-Up

- [ ] Compile and run the D3D12 worker on Windows MSVC hardware.
- [ ] Compile and run the Vulkan worker on a Linux Wayland host.
- [ ] Record physical iOS, Android Vulkan, Android API 23 GLES, and signed
      HarmonyOS device evidence.
- [ ] Record Chrome WebGPU loss/recovery and performance evidence.
- [ ] Run the 10-minute performance, memory, 100 recreation/lifecycle, and
      forced context-loss gates per platform, then validate each manifest with
      `--require-passed` before changing `gpu_promoted`.
