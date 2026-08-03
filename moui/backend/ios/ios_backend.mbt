///|
/// Window-hosted native surface handle.
pub(all) struct IosSurfaceHandle {
  raw : UInt64
} derive(Eq, Debug, ToJson)

///|
pub fn IosSurfaceHandle::new(raw~ : UInt64) -> IosSurfaceHandle {
  { raw, }
}

///|
pub fn IosSurfaceHandle::none() -> IosSurfaceHandle {
  { raw: 0UL }
}

///|
pub fn IosSurfaceHandle::raw(self : IosSurfaceHandle) -> UInt64 {
  self.raw
}

///|
pub(all) struct IosBackendCapabilities {
  embedded_view : Bool
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
/// commitment is made without matching-simulator/device evidence. It does
/// **not** mean full L3 runtime promotion or GPU seven-gate claims.
///
/// `status` is a coarse evidence class: `experimental` until window-hosted
/// matching-simulator smoke and presenter verification close gaps.
pub(all) struct IosBackendReadiness {
  ready : Bool
  status : String
  blocked_by : Array[String]
  next_steps : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct IosBackendInfo {
  host_info : @host.HostAppInfo
  capabilities : IosBackendCapabilities
  services : @host.HostServiceCapabilities
  input : @host.HostInputCapabilities
  readiness : IosBackendReadiness
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct IosSurfaceBinding {
  priv create_renderer : (IosSurfaceHandle, @host.HostSurfaceMetrics) -> @render.HostRendererResolution?
  priv sync_surface : (IosSurfaceHandle, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @render.HostAsyncImageLoader?
}

///|

///|
pub fn IosSurfaceBinding::new(
  create_renderer~ : (IosSurfaceHandle, @host.HostSurfaceMetrics) -> @render.HostRendererResolution?,
  sync_surface? : (IosSurfaceHandle, @host.HostSurfaceMetrics) -> Unit = (
    _view,
    _metrics,
  ) => (),
  image_loader? : @render.HostAsyncImageLoader? = None,
) -> IosSurfaceBinding {
  { create_renderer, sync_surface, image_loader }
}

///|
pub fn ios_surface_binding(
  factories : Array[@render.RendererBindingFactory],
) -> IosSurfaceBinding {
  let image_source = @host_image_source.from_filesystem()
  IosSurfaceBinding::new(create_renderer=(surface, metrics) => {
    let renderer_metrics = @render.RendererSurfaceMetrics::new(
      logical_size=metrics.logical_size,
      physical_size=metrics.physical_size,
      scale_factor=metrics.scale_factor,
    )
    let present = @render.HostPresentTarget::new(
      description="iOS host CPU presenter",
      present=frame => {
        ios_present_pixels_to_view(
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
      @render.GpuHostSurfaceDescriptor::metal_layer(
        ios_metal_layer_for_view(surface.raw()),
      ) {
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
fn IosSurfaceBinding::create(
  self : IosSurfaceBinding,
  surface : IosSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
) -> @render.HostRendererResolution? {
  (self.create_renderer)(surface, metrics)
}

///|
fn IosSurfaceBinding::sync(
  self : IosSurfaceBinding,
  surface : IosSurfaceHandle,
  metrics : @host.HostSurfaceMetrics,
) -> Unit {
  (self.sync_surface)(surface, metrics)
}

///|
pub fn IosSurfaceBinding::has_async_image_loader(
  self : IosSurfaceBinding,
) -> Bool {
  self.image_loader is Some(_)
}

///|
pub fn create_session(
  runtime~ : @runtime.AppRuntime,
  surface~ : IosSurfaceHandle,
  metrics~ : @host.HostSurfaceMetrics,
  binding~ : IosSurfaceBinding,
) -> @embedded_runtime_backend.HostedRuntimeSession? {
  @embedded_runtime_backend.HostedRuntimeSession::create(
    runtime~,
    raw_handle=surface.raw(),
    metrics~,
    binding=host_surface_binding_from_ios(binding),
  )
}

///|
pub fn host_surface_binding_from_ios(
  binding : IosSurfaceBinding,
) -> @embedded_runtime_backend.HostSurfaceBinding {
  @embedded_runtime_backend.HostSurfaceBinding::new(
    create_renderer=fn(raw, metrics) {
      binding.create(IosSurfaceHandle::new(raw~), metrics)
    },
    sync=fn(raw, metrics) { binding.sync(IosSurfaceHandle::new(raw~), metrics) },
  )
}

///|
pub fn ios_service_capabilities() -> @host.HostServiceCapabilities {
  // Platform callbacks supply window-hosted services. Matching-simulator
  // evidence remains partial (see readiness.status).
  @host.HostServiceCapabilities::new(clipboard=true)
}

///|
pub fn ios_input_capabilities() -> @host.HostInputCapabilities {
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
pub fn ios_capability_matrix() -> IosBackendCapabilities {
  {
    embedded_view: true,
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
pub fn ios_readiness() -> IosBackendReadiness {
  {
    ready: false,
    status: "experimental",
    blocked_by: [
      "product_class=experimental: no development/demonstration usability commitment without matching-device evidence",
      "window-hosted iOS matching-simulator smoke still needs re-recording with --require-passed",
      "physical-device and real VoiceOver observations remain open", "GPU seven-gate promotion is not claimed (gpuPromotionEvidence.claimed=false)",
    ],
    next_steps: [
      "re-run MoUI Showcase window-hosted smoke on Simulator", "record actualPresenterRoute metal-direct evidence in checks/platforms/ios.json",
      "land GPU seven-gate claim only after matching-host promotion manifests pass",
    ],
  }
}

///|
pub fn backend_info() -> IosBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="iOS window-hosted native host (HostCmd/ApplicationHandler)",
    ),
    capabilities: ios_capability_matrix(),
    services: ios_service_capabilities(),
    input: ios_input_capabilities(),
    readiness: ios_readiness(),
    description: "iOS backend exposes a native-session contract: wzzc-dev/window/ios supplies a view/Metal surface and lifecycle/input callbacks, while application-supplied factories bind the renderer. The host path is experimental (ready=false, status=experimental): it compiles and host-sim tests pass, but no usability or product commitment is made until window-hosted matching-simulator L3 and presenter verification close remaining gaps.",
  }
}

///|
pub fn ios_capability_summary(
  services? : @host.HostServiceCapabilities = ios_service_capabilities(),
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=backend_info().host_info,
    services~,
    input=ios_input_capabilities(),
    label="iOS host",
    window_lifecycle=true,
    multi_window=false,
    text_input_available=true,
    ime_available=true,
    drag_drop_available=false,
    async_services=true,
    native_accessibility_available=true,
    web_view_available=false,
    web_view_description="iOS native WKWebView is not part of the current embedded-runtime host contract.",
    description="iOS embedded runtime backend with window HostCmd lifecycle and an ApplicationHandler session. The window embedder owns lifecycle, surface, input, IME, clipboard, and accessibility adaptation. Runtime evidence remains partial.",
  )
}
