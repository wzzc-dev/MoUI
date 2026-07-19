///|
/// App-independent iOS embedding adapter. Platform entrypoints provide only
/// runtime and renderer factories; lifecycle, input, frame pacing, and host
/// response routing stay with the platform backend.
priv struct IosEmbeddingAdapter {
  runtime_factory : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime
  provider_factory : () -> IosRendererProvider
  renderer_configure : (String) -> Bool
  renderer_status_json : () -> String
  session : Ref[IosRuntimeSession?]
}

///|
fn IosEmbeddingAdapter::new(
  runtime_factory~ : (@host.HostSurfaceMetrics) -> @runtime.AppRuntime,
  provider_factory~ : () -> IosRendererProvider,
  renderer_configure~ : (String) -> Bool,
  renderer_status_json~ : () -> String,
) -> IosEmbeddingAdapter {
  {
    runtime_factory,
    provider_factory,
    renderer_configure,
    renderer_status_json,
    session: Ref(None),
  }
}

///|
fn ios_embedding_scale(scale_factor : Double) -> Double {
  if scale_factor > 0.0 {
    scale_factor
  } else {
    1.0
  }
}

///|
fn ios_embedding_metrics(
  width : Int,
  height : Int,
  scale_factor : Double,
) -> @host.HostSurfaceMetrics {
  let scale = ios_embedding_scale(scale_factor)
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
fn ios_embedding_pointer_phase(phase : Int) -> @core.PointerPhase? {
  match phase {
    0 => Some(@core.PointerPhase::Down)
    1 => Some(@core.PointerPhase::Move)
    2 => Some(@core.PointerPhase::Up)
    3 => Some(@core.PointerPhase::Cancel)
    _ => None
  }
}

///|
fn ios_embedding_scroll_phase(phase : Int) -> @host.HostScrollPhase {
  match phase {
    0 => @host.HostScrollPhase::Started
    1 => @host.HostScrollPhase::Moved
    2 => @host.HostScrollPhase::Ended
    3 => @host.HostScrollPhase::Cancelled
    _ => @host.HostScrollPhase::Moved
  }
}

///|
fn IosEmbeddingAdapter::attach_view(
  self : IosEmbeddingAdapter,
  view_handle : UInt64,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  let metrics = ios_embedding_metrics(width, height, scale_factor)
  let view = IosViewHandle::new(raw=view_handle)
  let provider = (self.provider_factory)()
  match self.session.val {
    Some(session) => session.attach_view(view, metrics, provider)
    None => {
      let runtime = (self.runtime_factory)(metrics)
      match create_session(runtime~, view~, metrics~, provider~) {
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
fn IosEmbeddingAdapter::resize(
  self : IosEmbeddingAdapter,
  width : Int,
  height : Int,
  scale_factor : Double,
) -> Bool {
  match self.session.val {
    Some(session) => {
      ignore(session.resize(ios_embedding_metrics(width, height, scale_factor)))
      true
    }
    None => false
  }
}

///|
fn IosEmbeddingAdapter::dispatch_pointer(
  self : IosEmbeddingAdapter,
  phase : Int,
  x : Double,
  y : Double,
  time_ms : Double,
) -> Bool {
  match (self.session.val, ios_embedding_pointer_phase(phase)) {
    (Some(session), Some(pointer_phase)) => {
      let scale = ios_embedding_scale(session.metrics().scale_factor)
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
fn IosEmbeddingAdapter::dispatch_scroll(
  self : IosEmbeddingAdapter,
  x : Double,
  y : Double,
  delta_x : Double,
  delta_y : Double,
  phase : Int,
) -> Bool {
  match self.session.val {
    Some(session) => {
      let scale = ios_embedding_scale(session.metrics().scale_factor)
      ignore(
        session.dispatch(
          @host.HostEvent::Scroll(
            @host.HostScrollEvent::new(
              position=@core.Point::new(x=x / scale, y=y / scale),
              delta=@host.HostScrollDelta::Pixels(
                @core.Point::new(x=delta_x / scale, y=delta_y / scale),
              ),
              phase=ios_embedding_scroll_phase(phase),
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
fn IosEmbeddingAdapter::render_frame(self : IosEmbeddingAdapter) -> Bool {
  match self.session.val {
    Some(session) => {
      ignore(session.render_frame())
      true
    }
    None => false
  }
}

///|
fn IosEmbeddingAdapter::frame_tick(
  self : IosEmbeddingAdapter,
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
fn IosEmbeddingAdapter::take_host_updates_json(
  self : IosEmbeddingAdapter,
) -> String {
  match self.session.val {
    Some(session) => session.drain_host_updates_json()
    None => "[]"
  }
}

///|
fn IosEmbeddingAdapter::take_host_update_envelope_json(
  self : IosEmbeddingAdapter,
) -> String {
  match self.session.val {
    Some(session) => session.drain_host_update_envelope_json()
    None => "{\"schemaVersion\":1,\"sessionGeneration\":0,\"updates\":[]}"
  }
}

///|
fn IosEmbeddingAdapter::dispatch_host_response_envelope_json(
  self : IosEmbeddingAdapter,
  text : String,
) -> Bool {
  match self.session.val {
    Some(session) => session.dispatch_host_response_envelope_json(text)
    None => false
  }
}

///|
fn IosEmbeddingAdapter::dispatch_text_input(
  self : IosEmbeddingAdapter,
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
fn IosEmbeddingAdapter::dispatch_command(
  self : IosEmbeddingAdapter,
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
fn IosEmbeddingAdapter::dispatch_accessibility(
  self : IosEmbeddingAdapter,
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
fn ios_embedding_clipboard_result(
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
fn IosEmbeddingAdapter::complete_clipboard(
  self : IosEmbeddingAdapter,
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
          ios_embedding_clipboard_result(kind, text, bytes),
        ),
      )
    None => false
  }
}

///|
fn IosEmbeddingAdapter::complete_clipboard_v1(
  self : IosEmbeddingAdapter,
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
fn IosEmbeddingAdapter::detach_view(self : IosEmbeddingAdapter) -> Unit {
  match self.session.val {
    Some(session) => ignore(session.detach_view())
    None => ()
  }
}

///|
fn IosEmbeddingAdapter::destroy_application(self : IosEmbeddingAdapter) -> Unit {
  match self.session.val {
    Some(session) => session.dispose()
    None => ()
  }
  self.session.val = None
}

///|
fn IosEmbeddingAdapter::renderer_configure(
  self : IosEmbeddingAdapter,
  mode : String,
) -> Bool {
  (self.renderer_configure)(mode)
}

///|
fn IosEmbeddingAdapter::renderer_status_json(
  self : IosEmbeddingAdapter,
) -> String {
  (self.renderer_status_json)()
}
