# Mobile Mainline

- Native Skia is the Android/iOS/HarmonyOS mainline; native WGPU is diagnostic.
- Mobile services cross `moui/backend/host::MobileHostChannel`; platform shells
  own only JNI/Obj-C++/NAPI conversion and native API calls.
- HarmonyOS compatible SDK is API 20. Native XComponent callbacks are the only
  surface/pointer lifecycle source; ArkTS owns VSync and platform services.
- `SkiaRasterNative` remains the `auto` default/fallback until promotion.
  Explicit `skia-gpu` uses a worker-owned native path: Metal on macOS/iOS,
  D3D12 on Windows, Wayland Vulkan on Linux, Vulkan with EGL/GLES fallback on
  Android, and EGL/GLES on HarmonyOS. Source implementation is not promotion.
- Runtime threads record immutable `SkPicture`; the C++ worker retains only
  pictures and POD metadata. It owns GPU context/surface/swapchain/cache/sync,
  uses latest-wins frame submission, preserves ordered controls, and
  acknowledges detach before host handles are released.
- Queueing is not presentation. Providers count only `Presented`; desktop
  hosts poll `frame_pending` without duplicate submission, and Android/iOS/
  HarmonyOS drain worker completions on every VSync. `PictureRecorded` must
  never update first-frame or image-present trackers.
- Cached layers are nested pictures, and platform-view pixels are recorded into
  the active picture. `SkiaHybridRenderer` routes later frames to raster after
  terminal GPU failure while retaining the same `AppRuntime` and app state.
- Mobile runtime proof must use before/after pixels plus application receipt
  logs. Input injection or force-stop success alone is never proof.
- Mobile build entrypoints accept `--renderer auto|skia-gpu|skia-raster` and
  record requested/selected modes. Before promotion, `auto` selects raster;
  explicit `skia-gpu` exercises the unpromoted worker path and is build/smoke
  evidence only.
- iOS lifecycle handling observes `UISceneDidEnterBackgroundNotification` and
  `UISceneWillEnterForegroundNotification`; smoke detach evidence must contain
  the target application process line, not only the log query marker.
- iOS Simulator smoke uses `idb` accessibility frames for tap/swipe and HOME
  lifecycle input, with logs filtered to the current `simctl launch` PID.
  Mobile Info.plists keep `UILaunchScreen` to avoid legacy `320x480` scaling.
- Component Gallery mobile entrypoints open `Mobile Service Probe` directly.
  Recorder acceptance requires system text clipboard write/read, two distinct
  physical resize dimensions, accessibility tree/focus/action, and async-image
  loading/ready logs. PNG clipboard remains a separate cross-app device check.
- Xcode 26.3 `simctl io` has no rotate operation. iOS Simulator rotation uses
  Simulator menu UI scripting and therefore needs macOS Accessibility
  permission; VoiceOver preference writes alone are not focus/action evidence.
- Mobile smoke status is three-state: `passed` is complete, `partial` preserves
  useful evidence with missing observations, and `failed` means no usable
  runtime evidence. `--require-passed` accepts only `passed`.
