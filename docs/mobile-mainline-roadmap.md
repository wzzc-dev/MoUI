# Mobile Mainline And GPU Roadmap

This document is the implementation and promotion record for Android, iOS,
and HarmonyOS. Native Skia is the mobile mainline. Native WGPU remains a
diagnostic route.

## Current State

| Area | Implemented in source | Runtime evidence |
| --- | --- | --- |
| VSync | Android `Choreographer`, iOS `CADisplayLink`, HarmonyOS `displaySync.create()` drive `frame_tick`; input no longer presents synchronously | Matching-device full smoke pending |
| HarmonyOS input | Native XComponent is the only pointer/surface source; touch-slop arbitration emits pointer Cancel before Scroll Begin/Move and suppresses Pointer Up while scrolling | Matching-device single-click and scroll-order proof pending |
| IME | Shared replace/selection events and mobile IME snapshots; Android `InputConnection`, iOS UIKit text proxy, HarmonyOS transparent `TextInput` proxy | Chinese composition, emoji/ZWJ, selection, candidate-anchor device proof pending |
| Clipboard | Async host channel with text and image payloads; Android `ClipboardManager`/`FileProvider`, iOS `UIPasteboard`, HarmonyOS pasteboard ArrayBuffer path | Cross-app text/PNG round-trip proof pending |
| Accessibility | Revisioned flat semantics snapshots and targeted runtime action routing; native virtual/container nodes on all three platforms | Tree, focus, and action screen-reader proof pending |
| Renderer selection | Formal `SkiaGpuNative`/`HostGpuSurface` descriptor and `auto`/`skia-gpu`/`skia-raster` selection; `MobileRendererSelection` carries `surface_route` | Product default: all native platforms `gpu_promoted=true`; `auto` selects GPU when available, raster on explicit request or recovery fallback |
| Renderer mailbox | Capacity-two latest-wins frame mailbox with non-droppable control messages and surface-generation rejection; native `std::thread` safely retains `SkPicture` plus POD metadata and acknowledges detach | Desktop hosts poll a pending frame without duplicate submission; mobile sessions drain completions each VSync; matching-device stress evidence remains pending |
| Context-loss recovery | `RendererRecovery` state machine in `moui/runtime/renderer_recovery.mbt` (Idle → Lost → Recovering → Recovered → Idle; terminal `FallbackToRaster` after 2 consecutive failures; 3-VSync deadline); hybrid rendering keeps the same runtime and routes later frames to raster | Mock fallback/state-preservation tests pass; matching-device forced-loss and deadline evidence pending |
| Direct GPU presentation | Worker-owned paths exist for iOS/macOS Metal, Android Vulkan/GLES, HarmonyOS EGL/GLES, Windows D3D12, and Linux Wayland Vulkan. Android GPU APK, HarmonyOS GPU HAP, and iOS simulator GPU App builds pass; macOS has a local first-frame smoke. | Physical iOS/Android/HarmonyOS, Windows MSVC, Linux Wayland, and full promotion manifests remain pending |
| Mobile runtime smoke | Recorder writes optional `renderer` (+ pending `gpuPromotionEvidence` skeleton when `gpuPromoted=true`, `claimed=false`) | iOS Simulator Component Gallery **`status=passed`** (`artifacts/mobile-runtime/ios/component_gallery/`, 2026-07-14); HarmonyOS host had no `hdc` target (packaging + scaffold only) |

`SkiaGpuNative` is the product `auto` default on all native Skia platforms when
a host GPU surface is available. `SkiaRasterNative` remains the explicit mode
and the sticky recovery fallback. Window-surface GPU paths exist for iOS/macOS
Metal, Android Vulkan/GLES, HarmonyOS EGL/GLES, Windows D3D12, and Linux
Wayland Vulkan. A GPU descriptor, offscreen GPU surface, or `PictureRecorded`
worker completion still does not count as direct presentation; full-frame
readback or platform image intermediates are forbidden on the GPU production
path.

All three mobile build entrypoints accept
`--renderer auto|skia-gpu|skia-raster`. The generated `mobile-build.json` and
native startup log record both requested and selected modes. For real Skia
packages, `auto` and `skia-gpu` select GPU (`gpuPromoted: true`); fallback-Skia
or explicit `skia-raster` stays raster.

Worker submission and presentation are separate contracts. A queued frame or
`PictureRecorded` completion does not advance first-frame or image-resource
tracking. Providers count only `Presented`; desktop event loops keep polling a
pending frame without recording it again, while Android, iOS, and HarmonyOS
drain completions from their platform VSync callbacks. Cached layers and
platform-view pixels are part of the immutable picture, so terminal GPU
fallback can replay the same content on raster without rebuilding app state.

## Mobile Host Channel

`moui/backend/host` owns `MobileHostChannel`, `MobileImeRequest`, revisioned
semantics snapshots, and JSON update/response envelopes. Android JNI, iOS
Obj-C++, and HarmonyOS NAPI only translate the common wire contract into native
platform services. Clipboard responses keep their request id and session
lifetime; responses arriving after disposal are ignored.

`AppRuntime::dispatch_semantics_action` first verifies that the current node
declares the requested action. It dispatches by `ElementId`, never by a second
screen-coordinate hit test. `SetText` uses `ReplaceText`; focus, activation,
submit, selection, expand/collapse/dismiss, and normalized scrolling use the
existing runtime/control paths.

## GPU Default And Evidence Contract

Product `auto` already selects GPU on every native Skia platform when the host
surface is available. Matching-device seven-gate manifests remain the bar for
claiming hardware-proven quality, not for enabling the default. A strong
manifest should still prove all of the following:

- direct window-surface presentation with zero full-frame CPU readback, RGBA
  copy, Bitmap, CGImage, UIImage, or PixelMap intermediates;
- renderer-thread ownership of the GPU context, surface, and persistent GPU
  resources, with UI/runtime state remaining on the runtime thread;
- a capacity-two latest-wins mailbox where resize, detach, context-loss, and
  shutdown controls are never dropped;
- p95 frame time at or below 16.7 ms at 60 Hz and 8.3 ms at 120 Hz after
  warm-up, dropped frames below 1% over ten minutes, and input-to-present p95
  no greater than two VSync intervals;
- bounded GPU memory without monotonic growth, 100 surface recreation and
  foreground/background cycles, and context-loss recovery within three VSyncs;
- automatic raster fallback after repeated GPU recovery failure while keeping
  the existing `AppRuntime` state.

Backend order for evidence collection remains iOS Metal, Android Vulkan with
GLES fallback, then HarmonyOS EGL/GLES followed by optional Vulkan. Worker-owned
source is connected and is the product default; incomplete manifests only mean
matching-device quality claims are still pending.

Desktop and Web use the shared schema illustrated by
`docs/gpu-promotion-manifest.example.json`. Validate a pending or diagnostic
manifest with:

```sh
node scripts/validate-gpu-promotion-manifest.mjs <manifest.json>
```

Release promotion must use `--require-passed`. The generic validator covers
macOS Metal, Windows D3D12, Linux Wayland Vulkan, Android Vulkan/EGL, iOS Metal,
HarmonyOS EGL/GLES, and WebGPU, including 60/120 Hz thresholds, a 600-second
run, 100 recreation/lifecycle cycles, provenance, recovery, and fallback. It
does not create evidence; matching-hardware runners must supply the manifest.

## Runtime Smoke

`scripts/record-mobile-runtime-smoke.mjs` supports `android`, `ios`, and
`harmonyos`. It records before/after screenshots, compares changed pixels, and
requires application receipt logs. A successful input injection command alone
cannot pass. Lifecycle detach must come from an app callback, not from a
successful force-stop/terminate command.

Manifest status is intentionally three-state: `passed` means every required
observation is proven, `partial` means the run produced useful matching-host
evidence but still has pending/no observations, and `failed` means the run did
not produce usable runtime evidence. `--require-passed` accepts only `passed`.

Component Gallery opens a dedicated `Mobile Service Probe` page on mobile. The
page has stable text-field and action labels, visible edit/action counters,
viewport dimensions, a deferred PNG, and scrollable tail content. The recorder
uses those controls to exercise IME edits, a system text-clipboard write/read
round trip, activation, rotation/resize, scrolling, and async-image second-frame
completion. Clipboard passes only after both `write-text` and `read-text`
completion logs. Resize passes only after the app logs two distinct physical
surface sizes, so a duplicate initial surface callback is not sufficient.
Portrait layouts keep Probe as the default while showing a compact
`Browse all components` entry that returns to the normal searchable component
index; the service probe is not a navigation dead end.

iOS Simulator input uses `idb`/`idb-companion`, since stock `simctl` does not
provide tap or swipe injection. The recorder waits for the accessibility tree,
taps an enabled button by frame, filters logs to the current launch PID, and
uses a HOME event to verify background detach. iOS templates declare
`UILaunchScreen` to prevent legacy `320x480` compatibility scaling.

Passed evidence additionally requires IME state plus edit logs, the clipboard
round trip, accessibility tree/focus/action logs, and both async-image loading
and ready observations. Use `--assistive-tech` only on a target where the real
platform screen reader is installed and enabled; ordinary coordinate taps do
not count as an accessibility action.
HarmonyOS uses `hdc`; release/manual suites for HarmonyOS Demo and Component
Gallery are registered in `smoke/gates.json`.

## Compatibility Floors

- Android: minSdk 23; Vulkan preference starts at API 24, with GLES on API 23.
- iOS: iOS 15.
- HarmonyOS: compatible SDK API 20 for the native accessibility baseline.
