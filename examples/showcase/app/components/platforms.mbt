///|
priv struct PlatformRuntimeInfo {
  id : PlatformId
  name : String
  route : String
  status : String
  command : String
  tone : @views.FeedbackTone
  badge_tone : @views.BadgeTone
  progress : Double
}

///|
pub fn platform_id_to_string(id : PlatformId) -> String {
  match id {
    PlatformId::MacOS => "macos"
    PlatformId::Linux => "linux"
    PlatformId::Windows => "windows"
    PlatformId::Android => "android"
    PlatformId::IOS => "ios"
    PlatformId::HarmonyOS => "harmonyos"
    PlatformId::Web => "web"
  }
}

///|
pub fn platform_id_from_string(id : String) -> PlatformId? {
  match id {
    "macos" => Some(PlatformId::MacOS)
    "linux" => Some(PlatformId::Linux)
    "windows" => Some(PlatformId::Windows)
    "android" => Some(PlatformId::Android)
    "ios" => Some(PlatformId::IOS)
    "harmonyos" => Some(PlatformId::HarmonyOS)
    "web" => Some(PlatformId::Web)
    _ => None
  }
}

///|
fn platform_runtime_infos() -> Array[PlatformRuntimeInfo] {
  [
    {
      id: PlatformId::MacOS,
      name: "macOS",
      route: "examples/showcase/macos_skia",
      status: "product",
      command: "moon run examples/showcase/macos_skia --target native",
      tone: @views.FeedbackTone::Success,
      badge_tone: @views.BadgeTone::Success,
      progress: 1.0,
    },
    {
      id: PlatformId::Linux,
      name: "Linux",
      route: "examples/showcase/linux_skia",
      status: "product (L3 partial)",
      command: "moon run examples/showcase/linux_skia --target native",
      tone: @views.FeedbackTone::Success,
      badge_tone: @views.BadgeTone::Success,
      progress: 0.9,
    },
    {
      id: PlatformId::Windows,
      name: "Windows",
      route: "examples/showcase/windows_skia",
      status: "product (L3 partial)",
      command: "moon run examples/showcase/windows_skia --target native",
      tone: @views.FeedbackTone::Success,
      badge_tone: @views.BadgeTone::Success,
      progress: 0.9,
    },
    {
      id: PlatformId::Android,
      name: "Android",
      route: "examples/showcase/android_window_hosted",
      status: "experimental",
      command: "moui build android showcase --mobile-config examples/showcase/moui.mobile.json",
      tone: @views.FeedbackTone::Warning,
      badge_tone: @views.BadgeTone::Warning,
      progress: 0.72,
    },
    {
      id: PlatformId::IOS,
      name: "iOS",
      route: "examples/showcase/ios_window_hosted",
      status: "experimental",
      command: "moui build ios showcase --mobile-config examples/showcase/moui.mobile.json",
      tone: @views.FeedbackTone::Warning,
      badge_tone: @views.BadgeTone::Warning,
      progress: 0.72,
    },
    {
      id: PlatformId::HarmonyOS,
      name: "HarmonyOS",
      route: "examples/showcase/harmonyos_window_hosted",
      status: "experimental",
      command: "moui build harmonyos showcase --mobile-config examples/showcase/moui.mobile.json",
      tone: @views.FeedbackTone::Warning,
      badge_tone: @views.BadgeTone::Warning,
      progress: 0.62,
    },
    {
      id: PlatformId::Web,
      name: "Web",
      route: "examples/showcase/web_wasm",
      status: "product",
      command: "moon build examples/showcase/web_wasm --target wasm-gc",
      tone: @views.FeedbackTone::Success,
      badge_tone: @views.BadgeTone::Success,
      progress: 0.9,
    },
  ]
}

///|
fn platform_runtime_info(id : PlatformId) -> PlatformRuntimeInfo {
  for info in platform_runtime_infos() {
    if info.id == id {
      return info
    }
  }
  platform_runtime_infos()[0]
}

///|
fn platform_display_name(id : PlatformId) -> String {
  platform_runtime_info(id).name
}

///|
pub fn session_path_label(backend : String, surface_route : String) -> String {
  let lower = backend.to_lower()
  if lower.contains("webgpu") {
    "GPU"
  } else if lower.contains("gpu") || surface_route.contains("gpu") {
    "GPU"
  } else if lower.contains("raster") ||
    lower.contains("cpu") ||
    surface_route == "raster" {
    "CPU"
  } else {
    "Unknown"
  }
}

///|
/// Build a session snapshot from host-measured strings so platform entrypoints
/// can inject live GPU/CPU selection without the shared app depending on
/// renderer packages.
pub fn session_runtime_from_selection(
  host~ : String,
  backend~ : String,
  surface_route~ : String,
  requested~ : String,
  gpu_available~ : Bool,
  gpu_promoted~ : Bool,
  note? : String = "",
) -> SessionRuntimeInfo {
  SessionRuntimeInfo::new(
    host~,
    path=session_path_label(backend, surface_route),
    backend~,
    surface_route~,
    requested~,
    gpu_available~,
    gpu_promoted~,
    note~,
  )
}
