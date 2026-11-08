# Windows GPU resize: reuse the per-HWND D3D12 swap chain instead of creating a second one

- **Status**: active
- **Goal**: Land the Windows GPU live-resize fix — the resize path must reuse the per-HWND D3D12 swap chain through the proven present-path drain/resize/recreate sequence instead of creating a second flip-model swap chain, which DXGI rejects and which routed interactive drag-resize into the invisible CPU fallback.

## Symptom

Interactive drag-resize of GPU-presented windows (`examples/showcase/windows_skia`
with `.render(@render_skia.gpu(...))` or `.render_all(@render_skia.from_env(...))`)
freezes the presented picture while the app stays responsive; closing the window
still works. The log shows `Skia GPU presenter deactivated; switching to the CPU
presenter at <WxH>` followed by no further visible updates. Pure raster
(`.render(@render_skia.raster())`, `MOUI_SKIA_RENDERER=raster`) resizes fine.

## Root cause

`skia_gpu_resize_window_surface` (`moui_skia_renderer/binding_factory.mbt`)
ignores the old surface on Windows and calls `skia_gpu_window_surface`, whose
C++ entry `moonbit_skia_surface_direct3d_window`
(`moui_skia/native/skia_stub_surface_image_data.cpp`) unconditionally runs
`CreateSwapChainForHwnd` — a second flip-model swap chain on an HWND that
already holds one (DXGI allows exactly one; the same constraint is recorded in
056b0021d). When that call fails (state-dependent: hot WM_SIZE streams next to
in-flight presents, DWM/driver state), the renderer marks its surface attachment
stale, the next frame's create fails again, `SurfaceUnavailable` routes into
`activate_fallback`, and the CPU (StretchDIBits) fallback presents underneath
the still-attached D3D swap chain, so DWM keeps showing the swap chain's last
frame — a permanently frozen picture with a live message pump.

Commit 056b0021d fixed exactly this class of failure for the PRESENT path
(drain Skia references, then ResizeBuffers, else release + recreate the swap
chain); the resize path never received the same treatment, which is why the
bug "came back".

## Fix

1. C++: add `moonbit_skia_surface_direct3d_resize_window` next to the present
   entry in `skia_stub_surface_image_data.cpp`. It consumes the old surface
   wrapper (which carries the live `MoonbitSkiaD3D12SwapChain` via
   `host_present_handle`), drains GPU references exactly like the present path
   (`freeGpuResources` + `flushAndSubmit` + `performDeferredCleanup(0)` + fence
   wait), then `ResizeBuffers` in place; if `ResizeBuffers` fails, release the
   swap chain and `CreateSwapChainForHwnd` at the new size; wrap the fresh back
   buffer and transfer ownership to the returned wrapper. Same failure contract
   as the present path (null surface wrapper => caller marks the attachment
   stale).
2. MoonBit: extern `native_surface_direct3d_resize_window` +
   `Surface::direct3d_resize_window` in `surface_image_data_native.mbt`; stub
   in `surface_image_data_unavailable.mbt`.
3. `binding_factory.mbt`: the Windows branch of `skia_gpu_resize_window_surface`
   calls `surface.direct3d_resize_window(...)` instead of
   `skia_gpu_window_surface(...)`.

## Verification

- `moon test moui_skia/native --target native` and
  `moon test moui_skia_renderer --target native` on the matching Windows host.
- GPU-path drag probe (SendInput border drag, rapid cadence) on the showcase
  `windows_skia` entrypoint: no fallback message, content hashes change, no
  hang.
- Matching-host interactive drag by the reporter (the original failure only
  reproduces inside the live drag loop).

## Follow-ups

- icudtl.dat staging: `scripts/windows-platform-evidence.sh` and
  `scripts/windows/package_windows_app_msvc.ps1` now stage/copy the release
  Skia package's `icudtl.dat` next to the executable (hard link when possible).
  Skia's `SkLoadICU` only searches the exe/module directories; the standard
  `ICU_DATA` environment variable is ignored (verified on the matching host).
  Still open: a plain `moon build` / `moon run` does not stage the file (it
  survives until `_build` is wiped); a durable fix needs either a data-file
  mechanism in moon or a per-package staging rule. Note the
  `moui_skia_renderer` whitebox tests crash (0xc0000005) when `icudtl.dat` is
  absent from their test directory.
