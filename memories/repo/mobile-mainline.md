# Mobile Mainline

- Native Skia is the Android/iOS/HarmonyOS mainline; native WGPU is diagnostic.
- Mobile services cross `moui/backend/host::MobileHostChannel`; platform shells
  own only native handles, provider creation, fixed-ABI translation, and native
  API calls. `MobileRuntimeSessionCore` lives at
  `moui/backend/internal/mobile_runtime`; `backend/host/internal` is not visible
  to Android/iOS/HarmonyOS sibling packages.
- Managed shells are package-owned and staged at build time: Kotlin/AndroidX
  with registered JNI on Android, SwiftUI around a `CAMetalLayer` view on iOS,
  and ArkTS `MoUIRoot` plus XComponent on HarmonyOS. App repositories keep
  schema v2 `mobile.json`, MoonBit entrypoints, resources, and bounded local
  plugins. Native project ownership requires a versioned eject.
- Managed shells negotiate `moui_mobile_get_runtime_api_v1()` and exchange Host
  Wire v1 envelopes scoped by `sessionGeneration`. Surface detach preserves
  `AppRuntime`; application destroy is terminal. Late generation responses are
  rejected.
- HarmonyOS compatible SDK is API 20. Native XComponent callbacks are the only
  surface/pointer lifecycle source; ArkTS owns VSync and platform services.
- Product default is `SkiaGpuNative` for `auto` on all native platforms when a
  host GPU surface is available (`NativeGpuPlatform::gpu_promoted` is true
  everywhere). Worker-owned paths: Metal on macOS/iOS, D3D12 on Windows,
  Wayland Vulkan on Linux, Vulkan with EGL/GLES fallback on Android, and
  EGL/GLES on HarmonyOS. `SkiaRasterNative` is explicit `skia-raster` plus sticky
  recovery fallback after terminal GPU failure.
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
  record requested/selected modes. For real Skia packages, `auto`/`skia-gpu`
  select GPU (`gpuPromoted: true`); fallback-Skia and explicit raster stay
  raster.
- iOS lifecycle handling observes `UISceneDidEnterBackgroundNotification` and
  `UISceneWillEnterForegroundNotification`; smoke detach evidence must contain
  the target application process line, not only the log query marker.
- iOS Simulator smoke uses `idb` accessibility frames for tap/swipe and HOME
  lifecycle input, with logs filtered to the current `simctl launch` PID.
  Mobile Info.plists keep `UILaunchScreen` to avoid legacy `320x480` scaling.
- Component Gallery mobile entrypoints expose the app workflow; automatic shell
  smoke behavior lives only in the repo-only `moui.mobile.test-probe` plugin.
  Recorder acceptance requires system text clipboard write/read, two distinct
  physical resize dimensions, accessibility tree/focus/action, PlatformView and
  Host Service completion, async-image loading/ready, GPU recovery, and stress
  logs. PNG clipboard remains a separate cross-app device check.
- Runtime evidence (2026-07-15): the iOS `passed` and Android `passed` artifacts
  belong to Release N UIKit/Java shells. Canonical SwiftUI/Kotlin shells need
  fresh matching-device runs. HarmonyOS canonical ArkTS evidence is `partial`.
  All three structured platform manifests remain `partial` and keep
  `actualPresenterRoute=unverified` until modern-shell evidence is recollected.
- Xcode 26.3 `simctl io` has no rotate operation. iOS Simulator rotation uses
  Simulator menu UI scripting and therefore needs macOS Accessibility
  permission; VoiceOver preference writes alone are not focus/action evidence.
- Runtime evidence (2026-07-14): iOS Simulator counter + component_gallery
  mobile-runtime smokes are `partial` under `artifacts/mobile-runtime/ios/` with
  product GPU configure/build metadata; seven-gate claims remain pending scaffolds
  under `artifacts/gpu-promotion/{ios,harmonyos}/scaffold-latest/`. HarmonyOS had
  no `hdc` target (packaging + first-frame screenshot only).
- Mobile smoke status is three-state: `passed` is complete, `partial` preserves
  useful evidence with missing observations, and `failed` means no usable
  runtime evidence. `--require-passed` accepts only `passed`.
