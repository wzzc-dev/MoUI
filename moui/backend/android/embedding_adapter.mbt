///|
/// App-independent Android embedding adapter. Platform entrypoints provide only
/// runtime and renderer factories; lifecycle, input, frame pacing, and host
/// response routing stay with the platform backend.
priv struct AndroidEmbeddingAdapter {
  runtime_factory : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime
  provider_factory : () -> AndroidRendererProvider
  renderer_configure : (String) -> Bool
  renderer_status_json : () -> String
  session : Ref[AndroidRuntimeSession?]
}

///|
fn AndroidEmbeddingAdapter::new(
  runtime_factory~ : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime,
  provider_factory~ : () -> AndroidRendererProvider,
  renderer_configure~ : (String) -> Bool,
  renderer_status_json~ : () -> String,
) -> AndroidEmbeddingAdapter {
  {
    runtime_factory,
    provider_factory,
    renderer_configure,
    renderer_status_json,
    session: Ref(None),
  }
}

///|
fn android_embedding_scale(scale_factor : Double) -> Double {
  if scale_factor > 0.0 {
    scale_factor
  } else {
    1.0
  }
}

///|
fn android_embedding_metrics(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> @host.HostSurfaceMetrics {
  let scale = android_embedding_scale(scale_factor)
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
fn android_embedding_pointer_phase(phase : Int) -> @core.PointerPhase? {
  match phase {
    0 => Some(@core.PointerPhase::Down)
    1 => Some(@core.PointerPhase::Move)
    2 => Some(@core.PointerPhase::Up)
    3 => Some(@core.PointerPhase::Cancel)
    _ => None
  }
}

///|
fn android_embedding_scroll_phase(phase : Int) -> @host.HostScrollPhase {
  match phase {
    0 => @host.HostScrollPhase::Started
    1 => @host.HostScrollPhase::Moved
    2 => @host.HostScrollPhase::Ended
    3 => @host.HostScrollPhase::Cancelled
    _ => @host.HostScrollPhase::Moved
  }
}

///|
fn AndroidEmbeddingAdapter::attach_surface(
  self : AndroidEmbeddingAdapter,
  surface_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  let metrics = android_embedding_metrics(width, height, scale_factor)
  let surface = AndroidSurfaceHandle::new(raw=surface_handle)
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
fn AndroidEmbeddingAdapter::resize(
  self : AndroidEmbeddingAdapter,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  match self.session.val {
    Some(session) => {
      ignore(
        session.resize(android_embedding_metrics(width, height, scale_factor)),
      )
      true
    }
    None => false
  }
}

///|
fn AndroidEmbeddingAdapter::dispatch_pointer(
  self : AndroidEmbeddingAdapter,
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  match (self.session.val, android_embedding_pointer_phase(phase)) {
    (Some(session), Some(pointer_phase)) => {
      let scale = android_embedding_scale(session.metrics().scale_factor)
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
fn AndroidEmbeddingAdapter::dispatch_scroll(
  self : AndroidEmbeddingAdapter,
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  phase : Int,
) -> Bool {
  match self.session.val {
    Some(session) => {
      let scale = android_embedding_scale(session.metrics().scale_factor)
      ignore(
        session.dispatch(
          @host.HostEvent::Scroll(
            @host.HostScrollEvent::new(
              position=@core.Point::new(x=x / scale, y=y / scale),
              delta=@host.HostScrollDelta::Pixels(
                @core.Point::new(x=delta_x / scale, y=delta_y / scale),
              ),
              phase=android_embedding_scroll_phase(phase),
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
fn AndroidEmbeddingAdapter::render_frame(
  self : AndroidEmbeddingAdapter,
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
fn AndroidEmbeddingAdapter::frame_tick(
  self : AndroidEmbeddingAdapter,
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
fn AndroidEmbeddingAdapter::take_host_updates_json(
  self : AndroidEmbeddingAdapter,
) -> String {
  match self.session.val {
    Some(session) => session.drain_host_updates_json()
    None => "[]"
  }
}

///|
fn AndroidEmbeddingAdapter::take_host_update_envelope_json(
  self : AndroidEmbeddingAdapter,
) -> String {
  match self.session.val {
    Some(session) => session.drain_host_update_envelope_json()
    None => "{\"schemaVersion\":1,\"sessionGeneration\":0,\"updates\":[]}"
  }
}

///|
fn AndroidEmbeddingAdapter::dispatch_host_response_envelope_json(
  self : AndroidEmbeddingAdapter,
  text : String,
) -> Bool {
  match self.session.val {
    Some(session) => session.dispatch_host_response_envelope_json(text)
    None => false
  }
}

///|
fn AndroidEmbeddingAdapter::dispatch_text_input(
  self : AndroidEmbeddingAdapter,
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
fn AndroidEmbeddingAdapter::dispatch_command(
  self : AndroidEmbeddingAdapter,
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
fn AndroidEmbeddingAdapter::dispatch_accessibility(
  self : AndroidEmbeddingAdapter,
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
fn android_embedding_clipboard_result(
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
fn AndroidEmbeddingAdapter::complete_clipboard(
  self : AndroidEmbeddingAdapter,
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
          android_embedding_clipboard_result(kind, text, bytes),
        ),
      )
    None => false
  }
}

///|
fn AndroidEmbeddingAdapter::complete_clipboard_v1(
  self : AndroidEmbeddingAdapter,
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
fn AndroidEmbeddingAdapter::detach_surface(
  self : AndroidEmbeddingAdapter,
) -> Unit {
  match self.session.val {
    Some(session) => ignore(session.detach_surface())
    None => ()
  }
}

///|
fn AndroidEmbeddingAdapter::destroy_application(
  self : AndroidEmbeddingAdapter,
) -> Unit {
  match self.session.val {
    Some(session) => session.dispose()
    None => ()
  }
  self.session.val = None
}

///|
fn AndroidEmbeddingAdapter::renderer_configure(
  self : AndroidEmbeddingAdapter,
  mode : String,
) -> Bool {
  (self.renderer_configure)(mode)
}

///|
fn AndroidEmbeddingAdapter::renderer_status_json(
  self : AndroidEmbeddingAdapter,
) -> String {
  (self.renderer_status_json)()
}
