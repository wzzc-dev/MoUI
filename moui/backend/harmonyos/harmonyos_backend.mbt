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
  surface_binding : Bool
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
pub struct HarmonyOSSurfaceBinding {
  priv create_renderer : (HarmonyOSSurfaceHandle, @host.HostSurfaceMetrics) -> @render.HostRendererResolution?
  priv sync_surface : (HarmonyOSSurfaceHandle, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @render.HostAsyncImageLoader?
}

///|

///|
pub fn HarmonyOSSurfaceBinding::new(
  create_renderer~ : (HarmonyOSSurfaceHandle, @host.HostSurfaceMetrics) -> @render.HostRendererResolution?,
  sync_surface? : (HarmonyOSSurfaceHandle, @host.HostSurfaceMetrics) -> Unit = (
    _surface,
    _metrics,
  ) => (),
  image_loader? : @render.HostAsyncImageLoader? = None,
) -> HarmonyOSSurfaceBinding {
  { create_renderer, sync_surface, image_loader }
}

///|
pub fn harmonyos_surface_binding(
  factories : Array[@render.RendererBindingFactory],
) -> HarmonyOSSurfaceBinding {
  let image_source = @host_image_source.from_filesystem()
  HarmonyOSSurfaceBinding::new(create_renderer=(surface, metrics) => {
    let renderer_metrics = @render.RendererSurfaceMetrics::new(
      logical_size=metrics.logical_size,
      physical_size=metrics.physical_size,
      scale_factor=metrics.scale_factor,
    )
    let present = @render.HostPresentTarget::new(
      description="HarmonyOS host CPU presenter",
      present=frame => {
        harmonyos_present_pixels_to_surface(
          surface.raw(),
          frame.width(),
          frame.height(),
          frame.row_bytes(),
          frame.pixels(),
          frame.pixels().length(),
        ) !=
        0
      },
    )
    let gpu_surface = match
      @render.GpuHostSurfaceDescriptor::egl_native_window(surface.raw()) {
      Some(descriptor) =>
        Some(
          @render.HostGpuSurfaceBridge::new(
            descriptor~,
            create_surface=_ => None,
            present=_ => true,
          ),
        )
      None => None
    }
    let kit = @render.HostSurfaceKit::new(
      surface=@render.SurfaceDescriptor::cpu_raster(
        width=renderer_metrics.logical_size.width,
        height=renderer_metrics.logical_size.height,
        scale_factor=renderer_metrics.scale_factor,
      ),
      metrics=renderer_metrics,
      cpu_present=Some(present),
      gpu_surface~,
      image_source=Some(image_source),
    )
    @render.resolve_host_renderer(factories, kit)
  })
}

///|
fn HarmonyOSSurfaceBinding::create(
  self : HarmonyOSSurfaceBinding,
  surface : HarmonyOSSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
) -> @render.HostRendererResolution? {
  (self.create_renderer)(surface, metrics)
}

///|
fn HarmonyOSSurfaceBinding::sync(
  self : HarmonyOSSurfaceBinding,
  surface : HarmonyOSSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
) -> Unit {
  (self.sync_surface)(surface, metrics)
}

///|
pub fn HarmonyOSSurfaceBinding::has_async_image_loader(
  self : HarmonyOSSurfaceBinding,
) -> Bool {
  self.image_loader is Some(_)
}

///|
pub fn create_session(
  runtime~ : @runtime.AppRuntime,
  surface~ : HarmonyOSSurfaceHandle,
  metrics~ : @host.HostSurfaceMetrics,
  binding~ : HarmonyOSSurfaceBinding,
) -> @embedded_runtime_backend.HostedRuntimeSession? {
  @embedded_runtime_backend.HostedRuntimeSession::create(
    runtime~,
    raw_handle=surface.raw(),
    metrics~,
    binding=host_surface_binding_from_harmonyos(binding),
  )
}

///|
pub fn host_surface_binding_from_harmonyos(
  binding : HarmonyOSSurfaceBinding,
) -> @embedded_runtime_backend.HostSurfaceBinding {
  @embedded_runtime_backend.HostSurfaceBinding::new(
    create_renderer=fn(raw, metrics) {
      binding.create(HarmonyOSSurfaceHandle::new(raw~), metrics)
    },
    sync=fn(raw, metrics) {
      binding.sync(HarmonyOSSurfaceHandle::new(raw~), metrics)
    },
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
    surface_binding: true,
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
    description: "HarmonyOS backend exposes a native-session contract: wzzc-dev/window/harmonyos supplies an XComponent native-window handle and lifecycle/input callbacks, while application-supplied factories bind the renderer. The host path is experimental (ready=false, status=experimental): it compiles and host-sim tests pass, but no usability or product commitment is made until signed-device full L3 smoke and presenter verification close remaining gaps.",
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

///|
/// The embedded host channel does not yet expose an app-facing service bridge.
pub fn app_environment() -> @services.AppEnvironment {
  @services.AppEnvironment::new()
}
