# Mobile Mainline

- Native Skia is the Android/iOS/HarmonyOS mainline; native WGPU is diagnostic.
- Mobile services cross `moui/backend/host::MobileHostChannel`; platform shells
  own only JNI/Obj-C++/NAPI conversion and native API calls.
- HarmonyOS compatible SDK is API 20. Native XComponent callbacks are the only
  surface/pointer lifecycle source; ArkTS owns VSync and platform services.
- `SkiaRasterNative` remains default/fallback. `SkiaGpuNative` is a formal
  `HostGpuSurface` descriptor but direct Metal/Vulkan/EGL presentation and
  renderer-thread integration are still pending.
- Mobile runtime proof must use before/after pixels plus application receipt
  logs. Input injection or force-stop success alone is never proof.
- Mobile build entrypoints accept `--renderer auto|skia-gpu|skia-raster` and
  record requested/selected modes. Until direct GPU presentation is promoted,
  `auto` and `skia-gpu` explicitly select `skia-raster`.
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
