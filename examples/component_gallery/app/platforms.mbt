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
    PlatformId::HarmonyOs => "harmonyos"
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
    "harmonyos" => Some(PlatformId::HarmonyOs)
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
      route: "examples/component_gallery/macos",
      status: "mainline",
      command: "moon run examples/component_gallery/macos --target native",
      tone: @views.FeedbackTone::Success,
      badge_tone: @views.BadgeTone::Success,
      progress: 1.0,
    },
    {
      id: PlatformId::Linux,
      name: "Linux",
      route: "examples/component_gallery/linux",
      status: "mainline",
      command: "moon run examples/component_gallery/linux --target native",
      tone: @views.FeedbackTone::Success,
      badge_tone: @views.BadgeTone::Success,
      progress: 0.9,
    },
    {
      id: PlatformId::Windows,
      name: "Windows",
      route: "examples/component_gallery/windows",
      status: "mainline",
      command: "moon run examples/component_gallery/windows --target native",
      tone: @views.FeedbackTone::Success,
      badge_tone: @views.BadgeTone::Success,
      progress: 0.9,
    },
    {
      id: PlatformId::Android,
      name: "Android",
      route: "examples/component_gallery/android + android_app",
      status: "packaged",
      command: "scripts/build-component-gallery-android-apk.sh",
      tone: @views.FeedbackTone::Info,
      badge_tone: @views.BadgeTone::Accent,
      progress: 0.72,
    },
    {
      id: PlatformId::IOS,
      name: "iOS",
      route: "examples/component_gallery/ios + ios_app",
      status: "packaged",
      command: "scripts/build-component-gallery-ios-app.sh",
      tone: @views.FeedbackTone::Info,
      badge_tone: @views.BadgeTone::Accent,
      progress: 0.72,
    },
    {
      id: PlatformId::HarmonyOs,
      name: "HarmonyOS",
      route: "examples/component_gallery/harmonyos + harmonyos_app",
      status: "packaged",
      command: "scripts/build-mobile-harmonyos-hap.sh --app component_gallery",
      tone: @views.FeedbackTone::Info,
      badge_tone: @views.BadgeTone::Accent,
      progress: 0.62,
    },
    {
      id: PlatformId::Web,
      name: "Web",
      route: "examples/component_gallery/web",
      status: "wasm-gc",
      command: "moon build examples/component_gallery/web --target wasm-gc",
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
