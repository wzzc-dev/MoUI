///|
/// App-independent HarmonyOS embedding adapter. Platform entrypoints provide only
/// runtime and renderer factories; lifecycle, input, frame pacing, and host
/// response routing stay with the platform backend.
priv struct HarmonyOsEmbeddingAdapter {
  runtime_factory : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime
  provider_factory : () -> HarmonyOsRendererProvider
  renderer_configure : (String) -> Bool
  renderer_status_json : () -> String
  session : Ref[HarmonyOsRuntimeSession?]
}

///|
fn HarmonyOsEmbeddingAdapter::new(
  runtime_factory~ : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime,
  provider_factory~ : () -> HarmonyOsRendererProvider,
  renderer_configure~ : (String) -> Bool,
  renderer_status_json~ : () -> String,
) -> HarmonyOsEmbeddingAdapter {
  {
    runtime_factory,
    provider_factory,
    renderer_configure,
    renderer_status_json,
    session: Ref(None),
  }
}

///|
fn harmonyos_embedding_scale(scale_factor : Double) -> Double {
  if scale_factor > 0.0 {
    scale_factor
  } else {
    1.0
  }
}

///|
fn harmonyos_embedding_metrics(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> @host.HostSurfaceMetrics {
  let scale = harmonyos_embedding_scale(scale_factor)
  @host.HostSurfaceMetrics::new(
    logical_size=@core.Size::new(
      width=width.to_double() / scale,
      height=height.to_double() / scale,
    ),
    physical_size=@core.Size::new(
      width=width.to_double(),
      height=height.to_double(),
    ),
    scale_factor=scale,
  )
}

///|
fn harmonyos_embedding_pointer_phase(phase : Int) -> @core.PointerPhase? {
  match phase {
    0 => Some(@core.PointerPhase::Down)
    1 => Some(@core.PointerPhase::Move)
    2 => Some(@core.PointerPhase::Up)
    3 => Some(@core.PointerPhase::Cancel)
    _ => None
  }
}

///|
fn harmonyos_embedding_scroll_phase(phase : Int) -> @host.HostScrollPhase {
  match phase {
    0 => @host.HostScrollPhase::Started
    1 => @host.HostScrollPhase::Moved
    2 => @host.HostScrollPhase::Ended
    3 => @host.HostScrollPhase::Cancelled
    _ => @host.HostScrollPhase::Moved
  }
}

///|
fn HarmonyOsEmbeddingAdapter::attach_surface(
  self : HarmonyOsEmbeddingAdapter,
  surface_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  let metrics = harmonyos_embedding_metrics(width, height, scale_factor)
  let surface = HarmonyOsSurfaceHandle::new(raw=surface_handle)
  let provider = (self.provider_factory)()
  match self.session.val {
    Some(session) => session.attach_surface(surface, metrics, provider)
    None => {
      let runtime = (self.runtime_factory)(metrics)
      match create_session(runtime~, surface~, metrics~, provider~) {
        Some(session) => {
          self.session.val = Some(session)
          true
        }
        None => false
      }
    }
  }
}

///|
fn HarmonyOsEmbeddingAdapter::resize(
  self : HarmonyOsEmbeddingAdapter,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  match self.session.val {
    Some(session) => {
      ignore(
        session.resize(harmonyos_embedding_metrics(width, height, scale_factor)),
      )
      true
    }
    None => false
  }
}

///|
fn HarmonyOsEmbeddingAdapter::dispatch_pointer(
  self : HarmonyOsEmbeddingAdapter,
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  match (self.session.val, harmonyos_embedding_pointer_phase(phase)) {
    (Some(session), Some(pointer_phase)) => {
      let scale = harmonyos_embedding_scale(session.metrics().scale_factor)
      ignore(
        session.dispatch(
          @host.HostEvent::Pointer(
            @core.PointerEvent::new(
              position=@core.Point::new(x=x / scale, y=y / scale),
              phase=pointer_phase,
              button=0,
              time_ms~,
            ),
          ),
        ),
      )
      true
    }
    _ => false
  }
}

///|
fn HarmonyOsEmbeddingAdapter::dispatch_scroll(
  self : HarmonyOsEmbeddingAdapter,
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  phase : Int,
) -> Bool {
  match self.session.val {
    Some(session) => {
      let scale = harmonyos_embedding_scale(session.metrics().scale_factor)
      ignore(
        session.dispatch(
          @host.HostEvent::Scroll(
            @host.HostScrollEvent::new(
              position=@core.Point::new(x=x / scale, y=y / scale),
              delta=@host.HostScrollDelta::Pixels(
                @core.Point::new(x=delta_x / scale, y=delta_y / scale),
              ),
              phase=harmonyos_embedding_scroll_phase(phase),
            ),
          ),
        ),
      )
      true
    }
    None => false
  }
}

///|
fn HarmonyOsEmbeddingAdapter::render_frame(
  self : HarmonyOsEmbeddingAdapter,
) -> Bool {
  match self.session.val {
    Some(session) => {
      ignore(session.render_frame())
      true
    }
    None => false
  }
}

///|
fn HarmonyOsEmbeddingAdapter::frame_tick(
  self : HarmonyOsEmbeddingAdapter,
  time_ms : Double,
) -> Bool {
  match self.session.val {
    Some(session) => {
      session.advance_time(time_ms)
      if session.take_redraw_requested() || session.runtime().needs_redraw() {
        ignore(session.render_frame())
        true
      } else {
        false
      }
    }
    None => false
  }
}

///|
fn HarmonyOsEmbeddingAdapter::take_host_updates_json(
  self : HarmonyOsEmbeddingAdapter,
) -> String {
  match self.session.val {
    Some(session) => session.drain_host_updates_json()
    None => "[]"
  }
}

///|
fn HarmonyOsEmbeddingAdapter::take_host_update_envelope_json(
  self : HarmonyOsEmbeddingAdapter,
) -> String {
  match self.session.val {
    Some(session) => session.drain_host_update_envelope_json()
    None => "{\"schemaVersion\":1,\"sessionGeneration\":0,\"updates\":[]}"
  }
}

///|
fn HarmonyOsEmbeddingAdapter::dispatch_host_response_envelope_json(
  self : HarmonyOsEmbeddingAdapter,
  text : String,
) -> Bool {
  match self.session.val {
    Some(session) => session.dispatch_host_response_envelope_json(text)
    None => false
  }
}

///|
fn HarmonyOsEmbeddingAdapter::dispatch_text_input(
  self : HarmonyOsEmbeddingAdapter,
  kind : Int,
  text : String,
  start : Int,
  end : Int,
) -> Bool {
  match
    (
      self.session.val,
      @embedded_runtime_session.embedding_text_input_response(
        kind, text, start, end,
      ),
    ) {
    (Some(session), Some(response)) => session.dispatch_host_response(response)
    _ => false
  }
}

///|
fn HarmonyOsEmbeddingAdapter::dispatch_command(
  self : HarmonyOsEmbeddingAdapter,
  kind : Int,
) -> Bool {
  match
    (
      self.session.val,
      @embedded_runtime_session.embedding_command_response(kind),
    ) {
    (Some(session), Some(response)) => session.dispatch_host_response(response)
    _ => false
  }
}

///|
fn HarmonyOsEmbeddingAdapter::dispatch_accessibility(
  self : HarmonyOsEmbeddingAdapter,
  element_id : Int,
  action : Int,
  value : String,
) -> Bool {
  match
    (
      self.session.val,
      @embedded_runtime_session.embedding_accessibility_response(
        element_id, action, value,
      ),
    ) {
    (Some(session), Some(response)) => session.dispatch_host_response(response)
    _ => false
  }
}

///|
fn harmonyos_embedding_clipboard_result(
  kind : Int,
  text : String,
  bytes : Bytes,
) -> @host.HostServiceResponse {
  match kind {
    1 => @host.HostServiceResponse::ClipboardText(text)
    2 => @host.HostServiceResponse::ClipboardImage(bytes)
    3 => @host.HostServiceResponse::ClipboardWritten
    _ => @host.HostServiceResponse::Unavailable(text)
  }
}

///|
fn HarmonyOsEmbeddingAdapter::complete_clipboard(
  self : HarmonyOsEmbeddingAdapter,
  id : Int,
  kind : Int,
  text : String,
  bytes : Bytes,
) -> Bool {
  match self.session.val {
    Some(session) =>
      session.dispatch_host_response(
        @embedded_runtime_session.EmbeddingHostResponse::Clipboard(
          @host.HostServiceRequestId::new(id),
          harmonyos_embedding_clipboard_result(kind, text, bytes),
        ),
      )
    None => false
  }
}

///|
fn HarmonyOsEmbeddingAdapter::complete_clipboard_v1(
  self : HarmonyOsEmbeddingAdapter,
  session_generation : Int,
  id : Int,
  kind : Int,
  text : String,
  bytes : Bytes,
) -> Bool {
  match self.session.val {
    Some(session) if session.session_generation() == session_generation =>
      self.complete_clipboard(id, kind, text, bytes)
    _ => false
  }
}

///|
fn HarmonyOsEmbeddingAdapter::detach_surface(
  self : HarmonyOsEmbeddingAdapter,
) -> Unit {
  match self.session.val {
    Some(session) => ignore(session.detach_surface())
    None => ()
  }
}

///|
fn HarmonyOsEmbeddingAdapter::destroy_application(
  self : HarmonyOsEmbeddingAdapter,
) -> Unit {
  match self.session.val {
    Some(session) => session.dispose()
    None => ()
  }
  self.session.val = None
}

///|
fn HarmonyOsEmbeddingAdapter::renderer_configure(
  self : HarmonyOsEmbeddingAdapter,
  mode : String,
) -> Bool {
  (self.renderer_configure)(mode)
}

///|
fn HarmonyOsEmbeddingAdapter::renderer_status_json(
  self : HarmonyOsEmbeddingAdapter,
) -> String {
  (self.renderer_status_json)()
}
