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
    MacOS => "macos"
    Linux => "linux"
    Windows => "windows"
    Android => "android"
    IOS => "ios"
    HarmonyOS => "harmonyos"
    Web => "web"
  }
}

///|
pub fn platform_id_from_string(id : String) -> PlatformId? {
  match id {
    "macos" => Some(MacOS)
    "linux" => Some(Linux)
    "windows" => Some(Windows)
    "android" => Some(Android)
    "ios" => Some(IOS)
    "harmonyos" => Some(HarmonyOS)
    "web" => Some(Web)
    _ => None
  }
}

///|
fn platform_runtime_infos() -> Array[PlatformRuntimeInfo] {
  [
    {
      id: MacOS,
      name: "macOS",
      route: "examples/showcase/macos_skia",
      status: "product",
      command: "moon run examples/showcase/macos_skia --target native",
      tone: Success,
      badge_tone: Success,
      progress: 1.0,
    },
    {
      id: Linux,
      name: "Linux",
      route: "examples/showcase/linux_skia",
      status: "product (L3 partial)",
      command: "moon run examples/showcase/linux_skia --target native",
      tone: Success,
      badge_tone: Success,
      progress: 0.9,
    },
    {
      id: Windows,
      name: "Windows",
      route: "examples/showcase/windows_skia",
      status: "product (L3 partial)",
      command: "moon run examples/showcase/windows_skia --target native",
      tone: Success,
      badge_tone: Success,
      progress: 0.9,
    },
    {
      id: Android,
      name: "Android",
      route: "examples/showcase/android_window_hosted",
      status: "experimental",
      command: "moui build android showcase --mobile-config examples/showcase/moui.mobile.json",
      tone: Warning,
      badge_tone: Warning,
      progress: 0.72,
    },
    {
      id: IOS,
      name: "iOS",
      route: "examples/showcase/ios_window_hosted",
      status: "experimental",
      command: "moui build ios showcase --mobile-config examples/showcase/moui.mobile.json",
      tone: Warning,
      badge_tone: Warning,
      progress: 0.72,
    },
    {
      id: HarmonyOS,
      name: "HarmonyOS",
      route: "examples/showcase/harmonyos_window_hosted",
      status: "experimental",
      command: "moui build harmonyos showcase --mobile-config examples/showcase/moui.mobile.json",
      tone: Warning,
      badge_tone: Warning,
      progress: 0.62,
    },
    {
      id: Web,
      name: "Web",
      route: "examples/showcase/web_wasm",
      status: "product",
      command: "moon build examples/showcase/web_wasm --target wasm-gc",
      tone: Success,
      badge_tone: Success,
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
