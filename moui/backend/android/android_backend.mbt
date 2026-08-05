///|
/// Window-hosted native surface handle.
pub(all) struct AndroidSurfaceHandle {
  raw : UInt64
} derive(Eq, Debug, ToJson)

///|
pub fn AndroidSurfaceHandle::new(raw~ : UInt64) -> AndroidSurfaceHandle {
  { raw, }
}

///|
pub fn AndroidSurfaceHandle::none() -> AndroidSurfaceHandle {
  { raw: 0UL }
}

///|
pub fn AndroidSurfaceHandle::raw(self : AndroidSurfaceHandle) -> UInt64 {
  self.raw
}

///|
pub(all) struct AndroidBackendCapabilities {
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
/// commitment is made without matching-device evidence. It does **not** mean
/// full L3 runtime promotion or GPU seven-gate claims.
///
/// `status` is a coarse evidence class: `experimental` until window-hosted
/// matching-device smoke and presenter verification close the remaining gaps.
pub(all) struct AndroidBackendReadiness {
  ready : Bool
  status : String
  blocked_by : Array[String]
  next_steps : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct AndroidBackendInfo {
  host_info : @host.HostAppInfo
  capabilities : AndroidBackendCapabilities
  services : @host.HostServiceCapabilities
  input : @host.HostInputCapabilities
  readiness : AndroidBackendReadiness
  description : String
} derive(Eq, Debug, ToJson)

///|
pub struct AndroidSurfaceBinding {
  priv create_renderer : (AndroidSurfaceHandle, @core.SurfaceMetrics) -> @render.RendererResolution?
  priv sync_surface : (AndroidSurfaceHandle, @core.SurfaceMetrics) -> Unit
  priv image_loader : @render.ImageLoader?
}

///|
pub fn AndroidSurfaceBinding::new(
  create_renderer~ : (AndroidSurfaceHandle, @core.SurfaceMetrics) -> @render.RendererResolution?,
  sync_surface? : (AndroidSurfaceHandle, @core.SurfaceMetrics) -> Unit = (
    _surface,
    _metrics,
  ) => (),
  image_loader? : @render.ImageLoader? = None,
) -> AndroidSurfaceBinding {
  { create_renderer, sync_surface, image_loader }
}

///|
/// Bind renderer factories to an Android window-hosted surface without
/// exposing the native window type outside this package.
pub fn android_surface_binding(
  factories : Array[@render.RendererFactory],
) -> AndroidSurfaceBinding {
  let shared = @embedded_runtime.mobile_host_surface_binding(
    factories,
    presenter_description="Android host CPU presenter",
    cpu_present=(raw_handle, frame) => {
      android_present_pixels_to_surface(
        raw_handle,
        frame.width(),
        frame.height(),
        frame.row_bytes(),
        frame.pixels(),
        frame.pixels().length(),
      ) !=
      0
    },
    gpu_descriptor=raw_handle => {
      @render.GpuHostSurfaceDescriptor::android_vulkan_window(raw_handle)
    },
  )
  AndroidSurfaceBinding::new(
    create_renderer=(_surface, metrics) => {
      (shared.create_renderer)(_surface.raw(), metrics)
    },
    sync_surface=(surface, metrics) => (shared.sync)(surface.raw(), metrics),
    image_loader=shared.image_loader,
  )
}

///|
fn AndroidSurfaceBinding::create(
  self : AndroidSurfaceBinding,
  surface : AndroidSurfaceHandle,
  metrics : @core.SurfaceMetrics,
) -> @render.RendererResolution? {
  (self.create_renderer)(surface, metrics)
}

///|
fn AndroidSurfaceBinding::sync(
  self : AndroidSurfaceBinding,
  surface : AndroidSurfaceHandle,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  (self.sync_surface)(surface, metrics)
}

///|
pub fn AndroidSurfaceBinding::has_async_image_loader(
  self : AndroidSurfaceBinding,
) -> Bool {
  self.image_loader is Some(_)
}

///|
pub fn host_surface_binding_from_android(
  binding : AndroidSurfaceBinding,
) -> @embedded_runtime.HostSurfaceBinding {
  @embedded_runtime.HostSurfaceBinding::new(
    create_renderer=fn(raw, metrics) {
      binding.create(AndroidSurfaceHandle::new(raw~), metrics)
    },
    sync=fn(raw, metrics) {
      binding.sync(AndroidSurfaceHandle::new(raw~), metrics)
    },
    image_loader=binding.image_loader,
  )
}

///|
pub fn android_service_capabilities() -> @host.HostServiceCapabilities {
  // Platform callbacks supply window-hosted services. Matching-device evidence
  // remains partial (see readiness.status).
  @host.HostServiceCapabilities::new(clipboard=true)
}

///|
pub fn android_input_capabilities() -> @host.HostInputCapabilities {
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
pub fn android_capability_matrix() -> AndroidBackendCapabilities {
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
pub fn android_readiness() -> AndroidBackendReadiness {
  {
    ready: false,
    status: "experimental",
    blocked_by: [
      "product_class=experimental: no development/demonstration usability commitment without matching-device evidence",
      "window-hosted Android matching-device smoke still needs re-recording", "real-device signing observation and verified direct presenter route remain open",
      "GPU seven-gate promotion is not claimed (gpuPromotionEvidence.claimed=false)",
    ],
    next_steps: [
      "re-run MoUI Showcase window-hosted smoke with --require-passed on emulator/device",
      "record actualPresenterRoute direct-present evidence in checks/platforms/android.json",
      "land GPU seven-gate claim only after matching-device promotion manifests pass",
    ],
  }
}

///|
pub fn backend_info() -> AndroidBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=@host.HostBackendKind::Native,
      description="Android window-hosted native host (HostCmd/ApplicationHandler)",
    ),
    capabilities: android_capability_matrix(),
    services: android_service_capabilities(),
    input: android_input_capabilities(),
    readiness: android_readiness(),
    description: "Android backend exposes a native-session contract: wzzc-dev/window/android supplies an ANativeWindow surface and lifecycle/input callbacks, while application-supplied factories bind the renderer. The host path is experimental (ready=false, status=experimental): it compiles and host-sim tests pass, but no usability or product commitment is made until window-hosted matching-device L3 and presenter verification close remaining gaps.",
  }
}

///|
pub fn android_capability_summary(
  services? : @host.HostServiceCapabilities = android_service_capabilities(),
) -> @host.HostCapabilitySummary {
  @host.HostCapabilitySummary::from_contracts(
    info=backend_info().host_info,
    services~,
    input=android_input_capabilities(),
    label="Android host",
    window_lifecycle=true,
    multi_window=false,
    text_input_available=true,
    ime_available=true,
    drag_drop_available=false,
    async_services=true,
    native_accessibility_available=true,
    web_view_available=false,
    web_view_description="Android native WebView is not part of the current embedded-runtime host contract.",
    description="Android embedded runtime backend with window HostCmd lifecycle and an ApplicationHandler session. The window embedder owns lifecycle, surface, input, IME, clipboard, and accessibility adaptation. Runtime evidence remains partial.",
  )
}

///|
/// The embedded host channel does not yet expose an app-facing service bridge.
/// Keep services unavailable until callbacks can complete typed tasks.
pub fn app_environment() -> @services.AppEnvironment {
  @services.AppEnvironment::new()
}
