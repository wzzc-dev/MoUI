///|
/// Window-hosted native surface handle.
#derive(Eq, Debug, ToJson)
pub(all) struct IosSurfaceHandle {
  raw : UInt64
}

///|
pub extend IosSurfaceHandle with Debug::{to_repr}

///|
pub extend IosSurfaceHandle with Eq::{not_equal, equal}

///|
pub extend IosSurfaceHandle with ToJson::{to_json}

///|
pub fn IosSurfaceHandle::new(raw~ : UInt64) -> IosSurfaceHandle {
  { raw, }
}

///|
pub fn IosSurfaceHandle::none() -> IosSurfaceHandle {
  { raw: 0UL, }
}

///|
pub fn IosSurfaceHandle::raw(self : IosSurfaceHandle) -> UInt64 {
  self.raw
}

///|
#derive(Eq, Debug, ToJson)
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
}

///|
pub extend IosBackendCapabilities with Debug::{to_repr}

///|
pub extend IosBackendCapabilities with Eq::{not_equal, equal}

///|
pub extend IosBackendCapabilities with ToJson::{to_json}

///|
/// `ready` means the window-hosted path is **experimental**: it compiles and
/// host-sim tests pass, but no development/demonstration usability or product
/// commitment is made without matching-simulator/device evidence. It does
/// **not** mean full L3 runtime promotion or GPU seven-gate claims.
///
/// `status` is a coarse evidence class: `experimental` until window-hosted
/// matching-simulator smoke and presenter verification close gaps.
#derive(Eq, Debug, ToJson)
pub(all) struct IosBackendReadiness {
  ready : Bool
  status : String
  blocked_by : Array[String]
  next_steps : Array[String]
}

///|
pub extend IosBackendReadiness with Debug::{to_repr}

///|
pub extend IosBackendReadiness with Eq::{not_equal, equal}

///|
pub extend IosBackendReadiness with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct IosBackendInfo {
  host_info : @host.HostAppInfo
  capabilities : IosBackendCapabilities
  services : @host.HostServiceCapabilities
  input : @host.HostInputCapabilities
  readiness : IosBackendReadiness
  description : String
}

///|
pub extend IosBackendInfo with Debug::{to_repr}

///|
pub extend IosBackendInfo with Eq::{not_equal, equal}

///|
pub extend IosBackendInfo with ToJson::{to_json}

///|
pub struct IosSurfaceBinding {
  priv create_renderer : (IosSurfaceHandle, @core.SurfaceMetrics) -> @render.RendererSession?
  priv sync_surface : (IosSurfaceHandle, @core.SurfaceMetrics) -> Unit
}

///|

///|
pub fn IosSurfaceBinding::new(
  create_renderer~ : (IosSurfaceHandle, @core.SurfaceMetrics) -> @render.RendererSession?,
  sync_surface~ : (IosSurfaceHandle, @core.SurfaceMetrics) -> Unit = (
    _view,
    _metrics,
  ) => (),
) -> IosSurfaceBinding {
  { create_renderer, sync_surface, }
}

///|
pub fn ios_surface_binding(
  providers : Array[@render.RendererProvider],
) -> IosSurfaceBinding {
  let shared = @embedded_runtime.mobile_host_surface_binding(
    providers,
    presenter_description="iOS host CPU presenter",
    cpu_present=(raw_handle, frame) => {
      ios_present_pixels_to_view(
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
      @render.NativeSurface::new(
        surface_handle=ios_metal_layer_for_view(raw_handle),
        present=_ => true,
      )
    },
  )
  IosSurfaceBinding::new(
    create_renderer=(surface, metrics) => {
      (shared.create_renderer)(surface.raw(), metrics)
    },
    sync_surface=(surface, metrics) => (shared.sync)(surface.raw(), metrics),
  )
}

///|
fn IosSurfaceBinding::create(
  self : IosSurfaceBinding,
  surface : IosSurfaceHandle,
  metrics : @core.SurfaceMetrics,
) -> @render.RendererSession? {
  (self.create_renderer)(surface, metrics)
}

///|
fn IosSurfaceBinding::sync(
  self : IosSurfaceBinding,
  surface : IosSurfaceHandle,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  (self.sync_surface)(surface, metrics)
}

///|
pub fn host_surface_binding_from_ios(
  binding : IosSurfaceBinding,
) -> @embedded_runtime.HostSurfaceBinding {
  @embedded_runtime.HostSurfaceBinding::new(
    create_renderer=fn(raw, metrics) {
      binding.create(IosSurfaceHandle::new(raw~), metrics)
    },
    sync=fn(raw, metrics) { binding.sync(IosSurfaceHandle::new(raw~), metrics) },
  )
}

///|
/// Capability values are the shared window-hosted mobile defaults; iOS
/// declares no deviation beyond its `embedded_view` matrix field name.
pub fn ios_service_capabilities() -> @host.HostServiceCapabilities {
  @embedded_runtime.mobile_service_capabilities()
}

///|
pub fn ios_input_capabilities() -> @host.HostInputCapabilities {
  @embedded_runtime.mobile_input_capabilities()
}

///|
pub fn ios_capability_matrix() -> IosBackendCapabilities {
  let defaults = @embedded_runtime.mobile_embedded_capabilities()
  {
    embedded_view: defaults.embedded_view,
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
pub fn ios_readiness() -> IosBackendReadiness {
  {
    ready: true,
    status: "passed",
    blocked_by: [],
    next_steps: [
      "keep the matching-simulator Showcase evidence current for pixels, pointer, keyboard/IME, clipboard read/write, accessibility, detach/recreate and async image",
      "record physical-device build/verify and VoiceOver observations; the simulator is the current evidence boundary",
      "land the metal-direct GPU seven-gate claim only after matching-host promotion manifests pass",
    ],
  }
}

///|
pub fn backend_info() -> IosBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=Native,
      description="iOS window-hosted native host (HostCmd/ApplicationHandler)",
    ),
    capabilities: ios_capability_matrix(),
    services: ios_service_capabilities(),
    input: ios_input_capabilities(),
    readiness: ios_readiness(),
    description: "iOS backend exposes a native-session contract: wzzc-dev/window/ios supplies a view/Metal surface and lifecycle/input callbacks, while application-supplied factories bind the renderer. The host path is committed (ready=true, status=passed) on matching-simulator R6 evidence; physical-device/VoiceOver observations and the metal-direct GPU claim remain quality items, not readiness blockers.",
  }
}

///|
pub fn ios_capability_summary(
  services~ : @host.HostServiceCapabilities = ios_service_capabilities(),
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

///|
/// Clipboard answers synchronously through the general UIPasteboard
/// (`ios_clipboard.mbt`), the same contract Android provides from the
/// embedder's JNI ClipboardManager bridge.
pub fn app_environment() -> @services.AppEnvironment {
  let clipboard = @services.ClipboardServices::new(
    read_text=() => {
      match ios_clipboard_read_text() {
        Some(text) =>
          @services.ServiceTask::succeed(
            key="ios:clipboard:read-text",
            value=text,
          )
        None =>
          @services.ServiceTask::fail(
            key="ios:clipboard:read-text",
            error=@services.ServiceError::unavailable(
              "clipboard does not contain text",
            ),
          )
      }
    },
    write_text=text => {
      if ios_clipboard_write_text(text) {
        @services.ServiceTask::succeed(key="ios:clipboard:write-text", value=())
      } else {
        @services.ServiceTask::fail(
          key="ios:clipboard:write-text",
          error=@services.ServiceError::unavailable("clipboard write failed"),
        )
      }
    },
  )
  @services.AppEnvironment::new(services=@services.AppServices::new(clipboard~))
}
