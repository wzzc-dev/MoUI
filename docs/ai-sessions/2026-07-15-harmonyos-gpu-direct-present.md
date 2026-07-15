# 2026-07-15 HarmonyOS GPU direct present

## Goal

Finish true GPU direct present on HarmonyOS HVD: Skia → EGL window backbuffer →
`eglSwapBuffers`, with no CPU full-frame blit on the success path.

## Root causes fixed

1. **`GrBackendRenderTargets::MakeGL` arg order** in HostGpu wrap
   (`skia_stub_surface_image_data.cpp` create + present rewrap): was
   `(w,h,stencil,samples)` → illegal `stencilBits=1`; now
   `(w,h,samples,stencil)` with stencil clamped to `{0,8,16}` (default FBO 0).
2. **Origin** aligned with GPU worker: **`kTopLeft_GrSurfaceOrigin`** (BottomLeft
   produced black XComponent even when swap returned true).
3. **`eglSwapInterval(1)`** after window create; **`eglMakeCurrent(window)`**
   before flush when `host_present_handle` is an EGL window.
4. **Sticky raster** only on PresentFailed / SurfaceUnavailable / GPU context
   failure — not incomplete draws; dispose drops EGL window before raster reuse.
5. **Evidence hilog:** `egl present ok=1 swap=1 w=… h=…` (≠ `present flushed`).

## Evidence (HVD MateBook Pro, `127.0.0.1:5557`)

```text
selected=skia-gpu-native surfaceRoute=egl-gpu gpuAvailable=true
egl present ok=1 swap=1 w=2090 h=1324
# no sticky fallback; no present flushed on success path
# nonblank screenshot center; process survives ≥12s
```

## Commands

```sh
scripts/build-mobile-harmonyos-hap.sh --app component_gallery --renderer auto
hdc -t 127.0.0.1:5557 install artifacts/harmonyos/component_gallery/ComponentGallery.hap
hdc -t 127.0.0.1:5557 shell aa start -a EntryAbility -b dev.wzzc.moui.componentgallery
hdc -t 127.0.0.1:5557 shell "hilog -T MoUIHarmony -z 200" | rg 'configure|egl present|sticky|present flushed'
```

## Still open

- Full smoke `status=passed` service gates
- Seven-gate L3 claim (not claimed)
- Android L2 full smoke after HOS (memory: not concurrent)
