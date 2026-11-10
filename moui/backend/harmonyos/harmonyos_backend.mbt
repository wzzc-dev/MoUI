///|
/// Window-hosted native surface handle.
#derive(Eq, Debug, ToJson)
pub(all) struct HarmonyOSSurfaceHandle {
  raw : UInt64
}

///|
pub extend HarmonyOSSurfaceHandle with Debug::{to_repr}

///|
pub extend HarmonyOSSurfaceHandle with Eq::{not_equal, equal}

///|
pub extend HarmonyOSSurfaceHandle with ToJson::{to_json}

///|
pub fn HarmonyOSSurfaceHandle::new(raw~ : UInt64) -> HarmonyOSSurfaceHandle {
  { raw, }
}

///|
pub fn HarmonyOSSurfaceHandle::none() -> HarmonyOSSurfaceHandle {
  { raw: 0UL, }
}

///|
pub fn HarmonyOSSurfaceHandle::raw(self : HarmonyOSSurfaceHandle) -> UInt64 {
  self.raw
}

///|
#derive(Eq, Debug, ToJson)
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
}

///|
pub extend HarmonyOSBackendCapabilities with Debug::{to_repr}

///|
pub extend HarmonyOSBackendCapabilities with Eq::{not_equal, equal}

///|
pub extend HarmonyOSBackendCapabilities with ToJson::{to_json}

///|
/// `ready` means the window-hosted path is **experimental**: it compiles and
/// host-sim tests pass, but no development/demonstration usability or product
/// commitment is made without signed-device evidence. It does **not** mean
/// full L3 runtime promotion, commercial signing, or GPU seven-gate claims.
///
/// `status` is a coarse evidence class: `experimental` until signed-device
/// full smoke and presenter verification close remaining gaps.
#derive(Eq, Debug, ToJson)
pub(all) struct HarmonyOSBackendReadiness {
  ready : Bool
  status : String
  blocked_by : Array[String]
  next_steps : Array[String]
}

///|
pub extend HarmonyOSBackendReadiness with Debug::{to_repr}

///|
pub extend HarmonyOSBackendReadiness with Eq::{not_equal, equal}

///|
pub extend HarmonyOSBackendReadiness with ToJson::{to_json}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct HarmonyOSBackendInfo {
  host_info : @host.HostAppInfo
  capabilities : HarmonyOSBackendCapabilities
  services : @host.HostServiceCapabilities
  input : @host.HostInputCapabilities
  readiness : HarmonyOSBackendReadiness
  description : String
}

///|
pub extend HarmonyOSBackendInfo with Debug::{to_repr}

///|
pub extend HarmonyOSBackendInfo with Eq::{not_equal, equal}

///|
pub extend HarmonyOSBackendInfo with ToJson::{to_json}

///|
pub struct HarmonyOSSurfaceBinding {
  priv create_renderer : (HarmonyOSSurfaceHandle, @core.SurfaceMetrics) -> @render.RendererSession?
  priv sync_surface : (HarmonyOSSurfaceHandle, @core.SurfaceMetrics) -> Unit
}

///|

///|
pub fn HarmonyOSSurfaceBinding::new(
  create_renderer~ : (HarmonyOSSurfaceHandle, @core.SurfaceMetrics) -> @render.RendererSession?,
  sync_surface~ : (HarmonyOSSurfaceHandle, @core.SurfaceMetrics) -> Unit = (
    _surface,
    _metrics,
  ) => (),
) -> HarmonyOSSurfaceBinding {
  { create_renderer, sync_surface, }
}

///|
pub fn harmonyos_surface_binding(
  providers : Array[@render.RendererProvider],
) -> HarmonyOSSurfaceBinding {
  let shared = @embedded_runtime.mobile_host_surface_binding(
    providers,
    presenter_description="HarmonyOS host CPU presenter",
    cpu_present=(raw_handle, frame) => {
      harmonyos_present_pixels_to_surface(
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
  HarmonyOSSurfaceBinding::new(
    create_renderer=(surface, metrics) => {
      (shared.create_renderer)(surface.raw(), metrics)
    },
    sync_surface=(surface, metrics) => (shared.sync)(surface.raw(), metrics),
  )
}

///|
fn HarmonyOSSurfaceBinding::create(
  self : HarmonyOSSurfaceBinding,
  surface : HarmonyOSSurfaceHandle,
  metrics : @core.SurfaceMetrics,
) -> @render.RendererSession? {
  (self.create_renderer)(surface, metrics)
}

///|
fn HarmonyOSSurfaceBinding::sync(
  self : HarmonyOSSurfaceBinding,
  surface : HarmonyOSSurfaceHandle,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  (self.sync_surface)(surface, metrics)
}

///|
pub fn host_surface_binding_from_harmonyos(
  binding : HarmonyOSSurfaceBinding,
) -> @embedded_runtime.HostSurfaceBinding {
  @embedded_runtime.HostSurfaceBinding::new(
    create_renderer=fn(raw, metrics) {
      binding.create(HarmonyOSSurfaceHandle::new(raw~), metrics)
    },
    sync=fn(raw, metrics) {
      binding.sync(HarmonyOSSurfaceHandle::new(raw~), metrics)
    },
  )
}

///|
/// Capability values are the shared window-hosted mobile defaults; HarmonyOS
/// declares no deviation beyond its `embedded_surface` matrix field name.
pub fn harmonyos_service_capabilities() -> @host.HostServiceCapabilities {
  @embedded_runtime.mobile_service_capabilities()
}

///|
pub fn harmonyos_input_capabilities() -> @host.HostInputCapabilities {
  @embedded_runtime.mobile_input_capabilities()
}

///|
pub fn harmonyos_capability_matrix() -> HarmonyOSBackendCapabilities {
  let defaults = @embedded_runtime.mobile_embedded_capabilities()
  {
    // Deviation declaration: HarmonyOS publishes the shared `embedded_view`
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
/// Host availability for the window-hosted HarmonyOS path.
///
/// Matching-device evidence covers every R6 capability: pixels, input,
/// detach/recreate, IME, clipboard read and write, accessibility, and async
/// image. `next_steps` keeps the operational notes that are not gaps, plus the
/// one platform constraint worth knowing (pasteboard read requires the ArkTS
/// PasteButton security control). See
/// `checks/platforms/harmonyos.json` `runtimeL3.evidence` for the log lines.
pub fn harmonyos_readiness() -> HarmonyOSBackendReadiness {
  {
    ready: true,
    status: "passed",
    blocked_by: [],
    next_steps: [
      "keep the matching-device Showcase evidence current for pixels, pointer, keyboard/IME, resize, clipboard read/write, accessibility, detach/recreate and async image",
      "clipboard read depends on the ArkTS PasteButton security control: a direct OH_Pasteboard_GetData call returns ERR_PERMISSION_ERROR (201) for a normal-level HAP because ohos.permission.READ_PASTEBOARD is system_basic + user_grant",
      "accessibility answers ArkUI provider callbacks from the runtime semantics snapshot; focus-move order currently follows the published node order",
      "land the GPU seven-gate claim only after matching-device promotion manifests pass",
    ],
  }
}

///|
pub fn backend_info() -> HarmonyOSBackendInfo {
  {
    host_info: @host.HostAppInfo::new(
      backend=Native,
      description="HarmonyOS window-hosted native host (HostCmd/ApplicationHandler)",
    ),
    capabilities: harmonyos_capability_matrix(),
    services: harmonyos_service_capabilities(),
    input: harmonyos_input_capabilities(),
    readiness: harmonyos_readiness(),
    description: "HarmonyOS backend exposes a native-session contract: wzzc-dev/window/harmonyos supplies an XComponent native-window handle and lifecycle/input callbacks, while application-supplied factories bind the renderer. The host path is committed (ready=true, status=passed) on matching-device R6 evidence; the GPU seven-gate claim remains a quality item, not a readiness blocker.",
  }
}

///|
pub fn harmonyos_capability_summary(
  services~ : @host.HostServiceCapabilities = harmonyos_service_capabilities(),
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
/// App-facing environment for the window-hosted HarmonyOS path.
///
/// The clipboard is answered synchronously from the native pasteboard
/// (`harmonyos_clipboard.mbt` -> OH_Pasteboard) rather than through the
/// embedded request queue: `EmbeddedHostServices` only enqueues Clipboard
/// requests for a shell to drain, and the HarmonyOS template has no drainer, so
/// a queued request would never complete.
pub fn app_environment() -> @services.AppEnvironment {
  let clipboard = @services.ClipboardServices::new(
    read_text=() => {
      match harmonyos_clipboard_read_text() {
        Some(text) =>
          @services.ServiceTask::succeed(
            key="harmonyos:clipboard:read-text",
            value=text,
          )
        None =>
          @services.ServiceTask::fail(
            key="harmonyos:clipboard:read-text",
            error=@services.ServiceError::unavailable(
              "clipboard does not contain text",
            ),
          )
      }
    },
    write_text=text => {
      if harmonyos_clipboard_write_text(text) {
        @services.ServiceTask::succeed(
          key="harmonyos:clipboard:write-text",
          value=(),
        )
      } else {
        @services.ServiceTask::fail(
          key="harmonyos:clipboard:write-text",
          error=@services.ServiceError::unavailable("clipboard write failed"),
        )
      }
    },
  )
  @services.AppEnvironment::new(services=@services.AppServices::new(clipboard~))
}
