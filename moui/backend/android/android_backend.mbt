///|
/// Window-hosted native surface handle.
#derive(Eq, Debug, ToJson)
pub(all) struct AndroidSurfaceHandle {
  raw : UInt64
}

///|
pub extend AndroidSurfaceHandle with Debug::{to_repr}

///|
pub extend AndroidSurfaceHandle with Eq::{not_equal, equal}

///|
pub extend AndroidSurfaceHandle with ToJson::{to_json}

///|
pub fn AndroidSurfaceHandle::new(raw~ : UInt64) -> AndroidSurfaceHandle {
  { raw, }
}

///|
pub fn AndroidSurfaceHandle::none() -> AndroidSurfaceHandle {
  { raw: 0UL, }
}

///|
pub fn AndroidSurfaceHandle::raw(self : AndroidSurfaceHandle) -> UInt64 {
  self.raw
}

///|
#derive(Eq, Debug, ToJson)
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
}

///|
pub extend AndroidBackendCapabilities with Debug::{to_repr}

///|
pub extend AndroidBackendCapabilities with Eq::{not_equal, equal}

///|
pub extend AndroidBackendCapabilities with ToJson::{to_json}

///|
/// `ready` means the window-hosted path is **experimental**: it compiles and
/// host-sim tests pass, but no development/demonstration usability or product
/// commitment is made without matching-device evidence. It does **not** mean
/// full L3 runtime promotion or GPU seven-gate claims.
///
/// `status` is a coarse evidence class: `experimental` until window-hosted
/// matching-device smoke and presenter verification close the remaining gaps.
#derive(Eq, Debug, ToJson)
pub(all) struct AndroidBackendReadiness {
  ready : Bool
  status : String
  blocked_by : Array[String]
  next_steps : Array[String]
}

///|
pub extend AndroidBackendReadiness with Debug::{to_repr}

///|
pub extend AndroidBackendReadiness with Eq::{not_equal, equal}

///|
pub extend AndroidBackendReadiness with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct AndroidBackendInfo {
  host_info : @host.HostAppInfo
  capabilities : AndroidBackendCapabilities
  services : @host.HostServiceCapabilities
  input : @host.HostInputCapabilities
  readiness : AndroidBackendReadiness
  description : String
}

///|
pub extend AndroidBackendInfo with Debug::{to_repr}

///|
pub extend AndroidBackendInfo with Eq::{not_equal, equal}

///|
pub extend AndroidBackendInfo with ToJson::{to_json}

///|
pub struct AndroidSurfaceBinding {
  priv create_renderer : (AndroidSurfaceHandle, @core.SurfaceMetrics) -> @render.RendererSession?
  priv sync_surface : (AndroidSurfaceHandle, @core.SurfaceMetrics) -> Unit
}

///|
pub fn AndroidSurfaceBinding::new(
  create_renderer~ : (AndroidSurfaceHandle, @core.SurfaceMetrics) -> @render.RendererSession?,
  sync_surface~ : (AndroidSurfaceHandle, @core.SurfaceMetrics) -> Unit = (
    _surface,
    _metrics,
  ) => (),
) -> AndroidSurfaceBinding {
  { create_renderer, sync_surface, }
}

///|
/// Bind renderer factories to an Android window-hosted surface without
/// exposing the native window type outside this package.
pub fn android_surface_binding(
  providers : Array[@render.RendererProvider],
) -> AndroidSurfaceBinding {
  let shared = @embedded_runtime.mobile_host_surface_binding(
    providers,
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
    native_surface=raw_handle => {
      @render.NativeSurface::new(surface_handle=raw_handle, present=_ => true)
    },
  )
  AndroidSurfaceBinding::new(
    create_renderer=(_surface, metrics) => {
      (shared.create_renderer)(_surface.raw(), metrics)
    },
    sync_surface=(surface, metrics) => (shared.sync)(surface.raw(), metrics),
  )
}

///|
fn AndroidSurfaceBinding::create(
  self : AndroidSurfaceBinding,
  surface : AndroidSurfaceHandle,
  metrics : @core.SurfaceMetrics,
) -> @render.RendererSession? {
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
  )
}

///|
/// Capability values are the shared window-hosted mobile defaults; Android
/// declares no deviation beyond its `embedded_surface` matrix field name.
pub fn android_service_capabilities() -> @host.HostServiceCapabilities {
  @embedded_runtime.mobile_service_capabilities()
}

///|
pub fn android_input_capabilities() -> @host.HostInputCapabilities {
  @embedded_runtime.mobile_input_capabilities()
}

///|
pub fn android_capability_matrix() -> AndroidBackendCapabilities {
  let defaults = @embedded_runtime.mobile_embedded_capabilities()
  {
    // Deviation declaration: Android publishes the shared `embedded_view`
    // value under the `embedded_surface` field name.
    embedded_surface: defaults.embedded_view,
    external_event_loop: defaults.external_event_loop,
    surface_binding: defaults.surface_binding,
    pointer: defaults.pointer,
    scroll: defaults.scroll,
    keyboard: defaults.keyboard,
    text_input: defaults.text_input,
    ime: defaults.ime,
    clipboard: defaults.clipboard,
    system_theme: defaults.system_theme,
    accessibility: defaults.accessibility,
    async_image: defaults.async_image,
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
      backend=Native,
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
  services~ : @host.HostServiceCapabilities = android_service_capabilities(),
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
/// Clipboard answers synchronously through the window embedder's JNI
/// ClipboardManager bridge (`android_clipboard.mbt`), the same contract
/// HarmonyOS provides from `harmonyos_backend.app_environment`.
pub fn app_environment() -> @services.AppEnvironment {
  let clipboard = @services.ClipboardServices::new(
    read_text=() => {
      match android_clipboard_read_text() {
        Some(text) =>
          @services.ServiceTask::succeed(
            key="android:clipboard:read-text",
            value=text,
          )
        None =>
          @services.ServiceTask::fail(
            key="android:clipboard:read-text",
            error=@services.ServiceError::unavailable(
              "clipboard does not contain text",
            ),
          )
      }
    },
    write_text=text => {
      if android_clipboard_write_text(text) {
        @services.ServiceTask::succeed(
          key="android:clipboard:write-text",
          value=(),
        )
      } else {
        @services.ServiceTask::fail(
          key="android:clipboard:write-text",
          error=@services.ServiceError::unavailable("clipboard write failed"),
        )
      }
    },
  )
  @services.AppEnvironment::new(services=@services.AppServices::new(clipboard~))
}
