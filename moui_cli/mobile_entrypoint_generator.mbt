///|
fn mobile_entrypoint_pkg_text(
  module_name : String,
  platform : String,
) -> String {
  let template =
    #|import {
    #|  "wzzc-dev/moui/core",
    #|  "wzzc-dev/moui/runtime",
    #|  "wzzc-dev/moui/backend/host",
    #|  "wzzc-dev/moui/backend/__PLATFORM__" @platform_host,
    #|  "wzzc-dev/moui/backend/__PLATFORM__/skia" @platform_skia,
    #|  "wzzc-dev/moui/render",
    #|  "__MODULE__/app" @app,
    #|}
    #|
    #|supported_targets = "native"
    #|
    #|pkgtype(kind: "executable")
    #|
    #|options(
    #|  link: {
    #|    "native": {
    #|      "exports": [
    #|        "moui_mobile_take_host_update_envelope_json",
    #|        "moui_mobile_dispatch_host_response_envelope_json",
    #|        "moui_mobile_renderer_configure",
    #|        "moui_mobile_renderer_status_json",
    #|        "moui_mobile_dispatch_text_input",
    #|        "moui_mobile_dispatch_command",
    #|        "moui_mobile_dispatch_accessibility",
    #|        "moui_mobile_complete_clipboard_v1",
    #|        "moui_mobile_attach_surface",
    #|        "moui_mobile_resize",
    #|        "moui_mobile_dispatch_pointer",
    #|        "moui_mobile_dispatch_scroll",
    #|        "moui_mobile_frame_tick",
    #|        "moui_mobile_render_frame",
    #|        "moui_mobile_detach_surface",
    #|        "moui_mobile_destroy_application",
    #|      ],
    #|    },
    #|  },
    #|  targets: { "main.mbt": [ "native" ] },
    #|)
  template
  .replace_all(old="__MODULE__", new=module_name)
  .replace_all(old="__PLATFORM__", new=platform)
}

///|
fn mobile_entrypoint_main_text(platform : String) -> String {
  let (
    session_type,
    handle_type,
    handle_argument,
    provider_type,
    attach_method,
    detach_method,
    gpu_platform,
    options_type,
    gpu_available,
    preflight,
  ) = match platform {
    "android" =>
      (
        "AndroidRuntimeSession", "AndroidSurfaceHandle", "surface", "AndroidRendererProvider",
        "attach_surface", "detach_surface", "Android", "AndroidSkiaAppOptions", "android_skia_gpu_available",
        "android_skia_provider_preflight_summary",
      )
    "ios" =>
      (
        "IosRuntimeSession", "IosViewHandle", "view", "IosRendererProvider", "attach_view",
        "detach_view", "Ios", "IosSkiaAppOptions", "ios_skia_gpu_available", "ios_skia_provider_preflight_summary",
      )
    "harmonyos" =>
      (
        "HarmonyOsRuntimeSession", "HarmonyOsSurfaceHandle", "surface", "HarmonyOsRendererProvider",
        "attach_surface", "detach_surface", "HarmonyOs", "HarmonyOsSkiaAppOptions",
        "harmonyos_skia_gpu_available", "harmonyos_skia_provider_preflight_summary",
      )
    _ => abort("unsupported mobile entrypoint platform: " + platform)
  }
  let template =
    #|///|
    #|let moui_mobile_session : Ref[@platform_host.__SESSION_TYPE__?] = Ref(None)
    #|
    #|///|
    #|fn moui_mobile_safe_scale(scale_factor : Double) -> Double {
    #|  if scale_factor > 0.0 { scale_factor } else { 1.0 }
    #|}
    #|
    #|///|
    #|fn moui_mobile_metrics(
    #|  width : Int,
    #|  height : Int,
    #|  scale_factor : Double,
    #|) -> @host.HostSurfaceMetrics {
    #|  let scale = moui_mobile_safe_scale(scale_factor)
    #|  @host.HostSurfaceMetrics::new(
    #|    logical_size=@core.Size::new(
    #|      width=width.to_double() / scale,
    #|      height=height.to_double() / scale,
    #|    ),
    #|    physical_size=@core.Size::new(
    #|      width=width.to_double(),
    #|      height=height.to_double(),
    #|    ),
    #|    scale_factor=scale,
    #|  )
    #|}
    #|
    #|///|
    #|fn moui_mobile_provider() -> @platform_host.__PROVIDER_TYPE__ {
    #|  @platform_skia.renderer_provider(options=moui_mobile_renderer_options())
    #|}
    #|
    #|///|
    #|fn moui_mobile_renderer_options() -> @platform_skia.__OPTIONS_TYPE__ {
    #|  let selection = @host.mobile_renderer_selection(
    #|    @render.NativeGpuPlatform::__GPU_PLATFORM__,
    #|    gpu_available=@platform_skia.__GPU_AVAILABLE__(),
    #|  )
    #|  @platform_skia.__OPTIONS_TYPE__::new(
    #|    surface_route=selection.surface_route,
    #|  )
    #|}
    #|
    #|///|
    #|fn moui_mobile_pointer_phase(phase : Int) -> @core.PointerPhase? {
    #|  match phase {
    #|    0 => Some(@core.PointerPhase::Down)
    #|    1 => Some(@core.PointerPhase::Move)
    #|    2 => Some(@core.PointerPhase::Up)
    #|    3 => Some(@core.PointerPhase::Cancel)
    #|    _ => None
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_attach_surface(
    #|  surface_handle : UInt64,
    #|  width : Int,
    #|  height : Int,
    #|  scale_factor : Double,
    #|) -> Bool {
    #|  let metrics = moui_mobile_metrics(width, height, scale_factor)
    #|  let handle = @platform_host.__HANDLE_TYPE__::new(raw=surface_handle)
    #|  let provider = moui_mobile_provider()
    #|  match moui_mobile_session.val {
    #|    Some(session) => session.__ATTACH_METHOD__(handle, metrics, provider)
    #|    None => {
    #|      let runtime = @runtime.new_program(
    #|        program=@app.program(),
    #|        size=metrics.logical_size,
    #|      )
    #|      match @platform_host.create_session(
    #|        runtime~,
    #|        __HANDLE_ARGUMENT__=handle,
    #|        metrics~,
    #|        provider~,
    #|      ) {
    #|        Some(session) => {
    #|          moui_mobile_session.val = Some(session)
    #|          true
    #|        }
    #|        None => {
    #|          runtime.destroy()
    #|          false
    #|        }
    #|      }
    #|    }
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_renderer_configure(mode : String) -> Bool {
    #|  @host.mobile_renderer_configure(mode)
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_renderer_status_json() -> String {
    #|  @host.mobile_renderer_status_json(
    #|    @render.NativeGpuPlatform::__GPU_PLATFORM__,
    #|    gpu_available=@platform_skia.__GPU_AVAILABLE__(),
    #|  )
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_resize(
    #|  width : Int,
    #|  height : Int,
    #|  scale_factor : Double,
    #|) -> Bool {
    #|  match moui_mobile_session.val {
    #|    Some(session) => {
    #|      ignore(session.resize(moui_mobile_metrics(width, height, scale_factor)))
    #|      true
    #|    }
    #|    None => false
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_dispatch_pointer(
    #|  phase : Int,
    #|  x : Double,
    #|  y : Double,
    #|  time_ms : Double,
    #|) -> Bool {
    #|  match (moui_mobile_session.val, moui_mobile_pointer_phase(phase)) {
    #|    (Some(session), Some(pointer_phase)) => {
    #|      let scale = moui_mobile_safe_scale(session.metrics().scale_factor)
    #|      ignore(session.dispatch(@host.HostEvent::Pointer(@core.PointerEvent::new(
    #|        position=@core.Point::new(x=x / scale, y=y / scale),
    #|        phase=pointer_phase,
    #|        button=0,
    #|        time_ms~,
    #|      ))))
    #|      true
    #|    }
    #|    _ => false
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_dispatch_scroll(
    #|  x : Double,
    #|  y : Double,
    #|  delta_x : Double,
    #|  delta_y : Double,
    #|  phase : Int,
    #|) -> Bool {
    #|  match moui_mobile_session.val {
    #|    Some(session) => {
    #|      let scale = moui_mobile_safe_scale(session.metrics().scale_factor)
    #|      let scroll_phase = match phase {
    #|        0 => @host.HostScrollPhase::Started
    #|        1 => @host.HostScrollPhase::Moved
    #|        2 => @host.HostScrollPhase::Ended
    #|        3 => @host.HostScrollPhase::Cancelled
    #|        _ => @host.HostScrollPhase::Moved
    #|      }
    #|      ignore(session.dispatch(@host.HostEvent::Scroll(@host.HostScrollEvent::new(
    #|        position=@core.Point::new(x=x / scale, y=y / scale),
    #|        delta=@host.HostScrollDelta::Pixels(
    #|          @core.Point::new(x=delta_x / scale, y=delta_y / scale),
    #|        ),
    #|        phase=scroll_phase,
    #|      ))))
    #|      true
    #|    }
    #|    None => false
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_render_frame() -> Bool {
    #|  match moui_mobile_session.val {
    #|    Some(session) => {
    #|      ignore(session.render_frame())
    #|      true
    #|    }
    #|    None => false
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_frame_tick(time_ms : Double) -> Bool {
    #|  match moui_mobile_session.val {
    #|    Some(session) => {
    #|      session.advance_time(time_ms)
    #|      if session.take_redraw_requested() || session.runtime().needs_redraw() {
    #|        ignore(session.render_frame())
    #|        true
    #|      } else {
    #|        false
    #|      }
    #|    }
    #|    None => false
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_take_host_update_envelope_json() -> String {
    #|  match moui_mobile_session.val {
    #|    Some(session) => session.drain_host_update_envelope_json()
    #|    None => "{\"schemaVersion\":1,\"sessionGeneration\":0,\"updates\":[]}"
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_dispatch_host_response_envelope_json(
    #|  text : String,
    #|) -> Bool {
    #|  match moui_mobile_session.val {
    #|    Some(session) => session.dispatch_host_response_envelope_json(text)
    #|    None => false
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_dispatch_text_input(
    #|  kind : Int,
    #|  text : String,
    #|  start : Int,
    #|  end : Int,
    #|) -> Bool {
    #|  match (
    #|    moui_mobile_session.val,
    #|    @host.mobile_text_input_response(kind, text, start, end),
    #|  ) {
    #|    (Some(session), Some(response)) => session.dispatch_host_response(response)
    #|    _ => false
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_dispatch_command(kind : Int) -> Bool {
    #|  match (moui_mobile_session.val, @host.mobile_command_response(kind)) {
    #|    (Some(session), Some(response)) => session.dispatch_host_response(response)
    #|    _ => false
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_dispatch_accessibility(
    #|  element_id : Int,
    #|  action : Int,
    #|  value : String,
    #|) -> Bool {
    #|  match (
    #|    moui_mobile_session.val,
    #|    @host.mobile_accessibility_response(element_id, action, value),
    #|  ) {
    #|    (Some(session), Some(response)) => session.dispatch_host_response(response)
    #|    _ => false
    #|  }
    #|}
    #|
    #|///|
    #|fn moui_mobile_complete_clipboard(
    #|  id : Int,
    #|  kind : Int,
    #|  text : String,
    #|  bytes : Bytes,
    #|) -> Bool {
    #|  match moui_mobile_session.val {
    #|    Some(session) => {
    #|      let result = match kind {
    #|        1 => @host.HostServiceResponse::ClipboardText(text)
    #|        2 => @host.HostServiceResponse::ClipboardImage(bytes)
    #|        3 => @host.HostServiceResponse::ClipboardWritten
    #|        _ => @host.HostServiceResponse::Unavailable(text)
    #|      }
    #|      session.dispatch_host_response(@host.MobileHostResponse::Clipboard(
    #|        @host.HostServiceRequestId::new(id),
    #|        result,
    #|      ))
    #|    }
    #|    None => false
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_complete_clipboard_v1(
    #|  session_generation : Int,
    #|  id : Int,
    #|  kind : Int,
    #|  text : String,
    #|  bytes : Bytes,
    #|) -> Bool {
    #|  match moui_mobile_session.val {
    #|    Some(session) if session.session_generation() == session_generation =>
    #|      moui_mobile_complete_clipboard(id, kind, text, bytes)
    #|    _ => false
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_detach_surface() -> Unit {
    #|  match moui_mobile_session.val {
    #|    Some(session) => ignore(session.__DETACH_METHOD__())
    #|    None => ()
    #|  }
    #|}
    #|
    #|///|
    #|pub fn moui_mobile_destroy_application() -> Unit {
    #|  match moui_mobile_session.val {
    #|    Some(session) => session.dispose()
    #|    None => ()
    #|  }
    #|  moui_mobile_session.val = None
    #|}
    #|
    #|///|
    #|fn main {
    #|  println(@platform_skia.__PREFLIGHT__())
    #|}
  template
  .replace_all(old="__SESSION_TYPE__", new=session_type)
  .replace_all(old="__HANDLE_TYPE__", new=handle_type)
  .replace_all(old="__HANDLE_ARGUMENT__", new=handle_argument)
  .replace_all(old="__PROVIDER_TYPE__", new=provider_type)
  .replace_all(old="__ATTACH_METHOD__", new=attach_method)
  .replace_all(old="__DETACH_METHOD__", new=detach_method)
  .replace_all(old="__GPU_PLATFORM__", new=gpu_platform)
  .replace_all(old="__OPTIONS_TYPE__", new=options_type)
  .replace_all(old="__GPU_AVAILABLE__", new=gpu_available)
  .replace_all(old="__PREFLIGHT__", new=preflight)
}
