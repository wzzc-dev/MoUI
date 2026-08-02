///|
/// Window-hosted native surface handle.
pub(all) struct HarmonyOSSurfaceHandle {
  raw : UInt64
} derive(Eq, Debug, ToJson)

///|
pub fn HarmonyOSSurfaceHandle::new(raw~ : UInt64) -> HarmonyOSSurfaceHandle {
  { raw, }
}

///|
pub fn HarmonyOSSurfaceHandle::none() -> HarmonyOSSurfaceHandle {
  { raw: 0UL }
}

///|
pub fn HarmonyOSSurfaceHandle::raw(self : HarmonyOSSurfaceHandle) -> UInt64 {
  self.raw
}

///|
pub(all) struct HarmonyOSBackendCapabilities {
  embedded_surface : Bool
  external_event_loop : Bool
  renderer_provider : Bool
  pointer : Bool
  scroll : Bool
  keyboard : Bool
  text_input : Bool
  ime : Bool
  clipboard : Bool
  system_theme : Bool
  accessibility : Bool
  async_image : Bool
} derive(Eq, Debug, ToJson)

///|
/// `ready` means the window-hosted path is **experimental**: it compiles and
/// host-sim tests pass, but no development/demonstration usability or product
/// commitment is made without signed-device evidence. It does **not** mean
/// full L3 runtime promotion, commercial signing, or GPU seven-gate claims.
///
/// `status` is a coarse evidence class: `experimental` until signed-device
/// full smoke and presenter verification close remaining gaps.
pub(all) struct HarmonyOSBackendReadiness {
  ready : Bool
  status : String
  blocked_by : Array[String]
  next_steps : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HarmonyOSBackendInfo {
  host_info : @host.HostAppInfo
  capabilities : HarmonyOSBackendCapabilities
  services : @host.HostServiceCapabilities
  input : @host.HostInputCapabilities
  readiness : HarmonyOSBackendReadiness
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct HarmonyOSRendererProvider {
  priv create_renderer : (HarmonyOSSurfaceHandle, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
  priv sync_surface : (HarmonyOSSurfaceHandle, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @render.HostAsyncImageLoader?
}

///|

///|
pub fn HarmonyOSRendererProvider::new(
  create_renderer~ : (HarmonyOSSurfaceHandle, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?,
  sync_surface? : (HarmonyOSSurfaceHandle, @host.HostSurfaceMetrics) -> Unit = (
    _surface,
    _metrics,
  ) => (),
  image_loader? : @render.HostAsyncImageLoader? = None,
) -> HarmonyOSRendererProvider {
  { create_renderer, sync_surface, image_loader }
}

///|
fn HarmonyOSRendererProvider::create(
  self : HarmonyOSRendererProvider,
  surface : HarmonyOSSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
) -> @render.HostWindowRenderer? {
  (self.create_renderer)(surface, metrics)
}

///|
fn HarmonyOSRendererProvider::sync(
  self : HarmonyOSRendererProvider,
  surface : HarmonyOSSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
) -> Unit {
  (self.sync_surface)(surface, metrics)
}

///|
pub fn HarmonyOSRendererProvider::has_async_image_loader(
  self : HarmonyOSRendererProvider,
) -> Bool {
  self.image_loader is Some(_)
}

///|
pub fn create_session(
  runtime~ : @runtime.AppRuntime,
  surface~ : HarmonyOSSurfaceHandle,
  metrics~ : @host.HostSurfaceMetrics,
  provider~ : HarmonyOSRendererProvider,
) -> @embedded_runtime_backend.HostedRuntimeSession? {
  @embedded_runtime_backend.HostedRuntimeSession::create(
    runtime~,
    raw_handle=surface.raw(),
    metrics~,
    adapter=renderer_provider_adapter_from_harmonyos(provider),
  )
}

///|
pub fn renderer_provider_adapter_from_harmonyos(
  provider : HarmonyOSRendererProvider,
) -> @embedded_runtime_backend.RendererProviderAdapter {
  @embedded_runtime_backend.RendererProviderAdapter::new(
    create_renderer=fn(raw, metrics) {
      provider.create(HarmonyOSSurfaceHandle::new(raw~), metrics)
    },
    sync=fn(raw, metrics) {
      provider.sync(HarmonyOSSurfaceHandle::new(raw~), metrics)
    },
    image_loader=provider.image_loader,
  )
}

///|
pub fn harmonyos_service_capabilities() -> @host.HostServiceCapabilities {
  // Platform callbacks supply window-hosted services. Matching-device evidence
  // remains partial (see readiness.status).
  @host.HostServiceCapabilities::new(clipboard=true)
}

///|
pub fn harmonyos_input_capabilities() -> @host.HostInputCapabilities {
  @host.HostInputCapabilities::new(
    pointer=true,
    scroll=true,
    keyboard=true,
    focus=true,
    text_input=true,
    ime=true,
    clipboard=true,
    drag_drop=false,
  )
}

///|
pub fn harmonyos_capability_matrix() -> HarmonyOSBackendCapabilities {
  {
    embedded_surface: true,
    external_event_loop: true,
    renderer_provider: true,
    pointer: true,
    scroll: true,
    keyboard: true,
    text_input: true,
    ime: true,
    clipboard: true,
    system_theme: false,
    accessibility: true,
    async_image: true,
  }
}

///|
pub fn harmonyos_readiness() -> HarmonyOSBackendReadiness {
  {
    ready: false,
    status: "experimental",
    blocked_by: [
      "product_class=experimental: no development/demonstration usability commitment without signed-device evidence",
      "commercial/signed-device window-hosted smoke is not yet status=passed", "checked-in smoke still lacks a complete attach/resize/input/IME/clipboard suite",
      "actualPresenterRoute remains unverified; GPU seven-gate promotion is not claimed",
    ],
    next_steps: [
      "configure MOUI_HARMONYOS_SIGNING_CONFIG and record a full matching-device smoke",
      "promote checks/platforms/harmonyos.json runtimeL3 only after --require-passed evidence",
      "land GPU seven-gate claim only after matching-device promotion manifests pass",
    ],
  }
}

///|
pub fn backend_info() -> HarmonyOSBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="HarmonyOS window-hosted native host (HostCmd/ApplicationHandler)",
    ),
    capabilities: harmonyos_capability_matrix(),
    services: harmonyos_service_capabilities(),
    input: harmonyos_input_capabilities(),
    readiness: harmonyos_readiness(),
    description: "HarmonyOS backend exposes a native-session contract: wzzc-dev/window/harmonyos supplies an XComponent native-window handle and lifecycle/input callbacks, while the backend selects a Skia renderer provider. The host path is experimental (ready=false, status=experimental): it compiles and host-sim tests pass, but no usability or product commitment is made until signed-device full L3 smoke and presenter verification close remaining gaps.",
  }
}

///|
pub fn harmonyos_capability_summary(
  services? : @host.HostServiceCapabilities = harmonyos_service_capabilities(),
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=backend_info().host_info,
    services~,
    input=harmonyos_input_capabilities(),
    label="HarmonyOS host",
    window_lifecycle=true,
    multi_window=false,
    text_input_available=true,
    ime_available=true,
    drag_drop_available=false,
    async_services=true,
    native_accessibility_available=true,
    web_view_available=false,
    web_view_description="HarmonyOS native WebView is not part of the current embedded-runtime host contract.",
    description="HarmonyOS embedded runtime backend with window HostCmd lifecycle and an ApplicationHandler session. The window embedder owns lifecycle, surface, input, IME, clipboard, and accessibility adaptation. Runtime evidence remains partial.",
  )
}
