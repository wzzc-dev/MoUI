///|
/// WeChat Mini Program backend capabilities and readiness.
/// Provides the host capability summary for the Mini Program platform.

///|
pub(all) struct WechatBackendCapabilities {
  canvas_surface : Bool
  pointer : Bool
  scroll : Bool
  keyboard : Bool
  text_input : Bool
  ime : Bool
  clipboard : Bool
  system_theme : Bool
} derive(Eq, Debug, ToJson)

///|
/// `ready` means the wasm-gc host path is **experimental**: it compiles, but
/// no development/demonstration usability or product commitment is made
/// without real Mini Program pixel smoke and touch event verification.
/// `status` is a coarse evidence class: `experimental` until those close
/// remaining gaps.
pub(all) struct WechatBackendReadiness {
  ready : Bool
  status : String
  blocked_by : Array[String]
  next_steps : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WechatBackendInfo {
  host_info : @host.HostAppInfo
  capabilities : WechatBackendCapabilities
  services : @host.HostServiceCapabilities
  input : @host.HostInputCapabilities
  readiness : WechatBackendReadiness
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn wechat_backend_info() -> @host.HostAppInfo {
  @host.HostAppInfo::new(
    backend=@host.HostBackendKind::Wechat,
    description="WeChat Mini Program Skyline canvas + wasm-gc host",
  )
}

///|
pub fn wechat_capabilities() -> WechatBackendCapabilities {
  {
    canvas_surface: true,
    pointer: true,
    scroll: true,
    keyboard: false,
    text_input: false,
    ime: false,
    clipboard: false,
    system_theme: false,
  }
}

///|
pub fn wechat_service_capabilities() -> @host.HostServiceCapabilities {
  @host.HostServiceCapabilities::new(
    clipboard=false,
    file_dialogs=false,
    file_access=false,
    open_url=false,
    system_theme=false,
  )
}

///|
pub fn wechat_input_capabilities() -> @host.HostInputCapabilities {
  @host.HostInputCapabilities::new(
    pointer=true,
    scroll=true,
    keyboard=false,
    focus=true,
    text_input=false,
    ime=false,
    clipboard=false,
    drag_drop=false,
  )
}

///|
pub fn wechat_capability_summary() -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=wechat_backend_info(),
    services=wechat_service_capabilities(),
    input=wechat_input_capabilities(),
    label="WeChat Mini Program host",
    window_lifecycle=true,
    multi_window=false,
    text_input_available=false,
    ime_available=false,
    drag_drop_available=false,
    async_services=false,
    native_accessibility_available=false,
    web_view_available=false,
  )
}

///|
pub fn app_environment() -> @services.AppEnvironment {
  @services.AppEnvironment::new()
}

///|
pub fn wechat_readiness() -> WechatBackendReadiness {
  {
    ready: false,
    status: "experimental",
    blocked_by: [
      "product_class=experimental: no usability commitment without real Mini Program evidence",
      "real-miniprogram-pixel-smoke", "touch-event-verification",
    ],
    next_steps: [
      "Build and run a counter demo in WeChat Developer Tools with Skyline", "Verify canvas rendering produces correct pixels",
      "Verify touch events dispatch correctly", "Record runtime evidence for promotion",
    ],
  }
}

///|
pub fn wechat_backend_full_info() -> WechatBackendInfo {
  {
    host_info: wechat_backend_info(),
    capabilities: wechat_capabilities(),
    services: wechat_service_capabilities(),
    input: wechat_input_capabilities(),
    readiness: wechat_readiness(),
    description: "WeChat Mini Program backend with a Skyline canvas host surface",
  }
}
