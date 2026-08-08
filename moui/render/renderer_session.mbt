///|
pub struct RendererPlatformViewCapability {
  priv draw_platform_view_pixels_fn : (
    Bytes,
    Int,
    Int,
    Int,
    Double,
    Double,
    Double,
    Double,
  ) -> Unit
  priv set_platform_view_draw_fn_fn : ((() -> Unit)?) -> Unit
}

///|
pub struct RendererGpuRecoveryCapability {
  priv inject_context_loss_fn : () -> Unit
  priv gpu_recovery_count_fn : () -> Int
  priv gpu_fallback_active_fn : () -> Bool
}

///|
/// Complete live renderer lifecycle for one host surface.
pub struct RendererSession {
  priv resize_fn : (@core.SurfaceMetrics) -> Unit
  priv render_frame_fn : (RenderFrameSubmission) -> RenderFrameResult
  priv drain_events_fn : () -> Array[RendererEvent]
  priv text_system_fn : () -> @core.TextSystem
  priv image_records_fn : () -> Array[ImageResourceRecord]
  priv apply_image_load_completion_fn : (ImageResourceLoadCompletion) -> Bool
  priv image_source : HostImageSource
  priv image_decoder : RendererImageDecoder?
  priv mut next_image_token : Int64
  priv mut image_tokens : Array[RendererImageLoadToken]
  priv mut image_sources : Array[String]
  priv mut image_events : Array[RendererEvent]
  priv present_count_fn : () -> Int
  priv recover_fn : (String) -> RecoveryResult
  priv dispose_fn : () -> Unit
  priv native_surface : NativeSurface?
  priv mut disposed : Bool
  priv platform_view : RendererPlatformViewCapability
  priv gpu_recovery : RendererGpuRecoveryCapability
}

///|
pub fn RendererPlatformViewCapability::new(
  draw_platform_view_pixels? : (
    Bytes,
    Int,
    Int,
    Int,
    Double,
    Double,
    Double,
    Double,
  ) -> Unit = fn(_pixels, _w, _h, _s, _dx, _dy, _dw, _dh) {  },
  set_platform_view_draw_fn? : ((() -> Unit)?) -> Unit = _fn => (),
) -> RendererPlatformViewCapability {
  {
    draw_platform_view_pixels_fn: draw_platform_view_pixels,
    set_platform_view_draw_fn_fn: set_platform_view_draw_fn,
  }
}

///|
pub fn RendererGpuRecoveryCapability::new(
  inject_context_loss? : () -> Unit = () => (),
  gpu_recovery_count? : () -> Int = () => 0,
  gpu_fallback_active? : () -> Bool = () => false,
) -> RendererGpuRecoveryCapability {
  {
    inject_context_loss_fn: inject_context_loss,
    gpu_recovery_count_fn: gpu_recovery_count,
    gpu_fallback_active_fn: gpu_fallback_active,
  }
}

///|
pub fn RendererSession::new(
  resize~ : (@core.SurfaceMetrics) -> Unit,
  render_frame~ : (RenderFrameSubmission) -> RenderFrameResult,
  drain_events? : (() -> Array[RendererEvent])? = None,
  text_system~ : () -> @core.TextSystem,
  present_count? : () -> Int = () => 0,
  recover? : (String) -> RecoveryResult = _ => RecoverySucceeded,
  dispose? : () -> Unit = () => (),
  image_records? : () -> Array[ImageResourceRecord] = () => [],
  apply_image_load_completion? : (ImageResourceLoadCompletion) -> Bool = _ => false,
  image_source? : HostImageSource = HostImageSource::unavailable(),
  image_decoder? : RendererImageDecoder? = None,
  native_surface? : NativeSurface? = None,
  platform_view? : RendererPlatformViewCapability = RendererPlatformViewCapability::new(),
  gpu_recovery? : RendererGpuRecoveryCapability = RendererGpuRecoveryCapability::new(),
) -> RendererSession {
  let drain_events_fn = match drain_events {
    Some(drain) => drain
    None => () => []
  }
  {
    resize_fn: resize,
    render_frame_fn: render_frame,
    drain_events_fn,
    text_system_fn: text_system,
    image_records_fn: image_records,
    apply_image_load_completion_fn: apply_image_load_completion,
    image_source,
    image_decoder,
    next_image_token: 1L,
    image_tokens: [],
    image_sources: [],
    image_events: [],
    present_count_fn: present_count,
    recover_fn: recover,
    dispose_fn: dispose,
    native_surface,
    disposed: false,
    platform_view,
    gpu_recovery,
  }
}

///|
pub fn RendererSession::resize(
  self : RendererSession,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  if !self.disposed {
    (self.resize_fn)(metrics)
  }
}

///|
pub fn RendererSession::render_frame(
  self : RendererSession,
  submission : RenderFrameSubmission,
) -> RenderFrameResult {
  if self.disposed {
    return RenderFrameResult::new(presented=false)
  }
  let result = (self.render_frame_fn)(submission)
  self.queue_image_requests()
  result
}

///|
pub fn RendererSession::drain_events(
  self : RendererSession,
) -> Array[RendererEvent] {
  if self.disposed {
    return []
  }
  self.queue_image_requests()
  let events = (self.drain_events_fn)()
  events.append(self.image_events)
  self.image_events = []
  events
}

///|
pub fn render_present_completion_is_presented(
  completion : RenderPresentCompletion,
) -> Bool {
  completion.status() is RenderPresentStatus::Presented
}

///|
pub fn render_present_completions_have_presented(
  completions : Array[RenderPresentCompletion],
) -> Bool {
  completions.any(render_present_completion_is_presented)
}

///|
pub fn render_present_completions_have_terminal(
  completions : Array[RenderPresentCompletion],
) -> Bool {
  completions.any(completion => {
    match completion.status() {
      RenderPresentStatus::Presented
      | RenderPresentStatus::Dropped
      | RenderPresentStatus::FallbackToRaster => true
      RenderPresentStatus::Recorded => false
    }
  })
}

///|
pub fn RendererSession::text_system(self : RendererSession) -> @core.TextSystem {
  (self.text_system_fn)()
}

///|
pub fn RendererSession::apply_image_load_completion(
  self : RendererSession,
  completion : RendererImageLoadCompletion,
) -> RendererImageCompletionResult {
  if self.disposed {
    return RendererImageCompletionResult::Disposed
  }
  guard self.take_image_request(completion.token()) is Some(source) else {
    return RendererImageCompletionResult::Stale
  }
  if source != completion.result().source {
    return RendererImageCompletionResult::Stale
  }
  RendererImageCompletionResult::Applied(
    (self.apply_image_load_completion_fn)(completion.result()),
  )
}

///|
pub fn RendererSession::image_diagnostics(
  self : RendererSession,
) -> RendererImageDiagnostics {
  RendererImageDiagnostics::new(
    records=(self.image_records_fn)(),
    pending_request_count=self.image_tokens.length(),
  )
}

///|
pub fn RendererSession::present_count(self : RendererSession) -> Int {
  (self.present_count_fn)()
}

///|
pub fn RendererSession::recover(
  self : RendererSession,
  reason : String,
) -> RecoveryResult {
  if self.disposed {
    RecoveryFailed("renderer session is disposed")
  } else {
    (self.recover_fn)(reason)
  }
}

///|
pub fn RendererSession::inject_context_loss(self : RendererSession) -> Unit {
  if !self.disposed {
    (self.gpu_recovery.inject_context_loss_fn)()
  }
}

///|
pub fn RendererSession::gpu_recovery_count(self : RendererSession) -> Int {
  (self.gpu_recovery.gpu_recovery_count_fn)()
}

///|
pub fn RendererSession::gpu_fallback_active(self : RendererSession) -> Bool {
  (self.gpu_recovery.gpu_fallback_active_fn)()
}

///|
pub fn RendererSession::dispose(self : RendererSession) -> Unit {
  if !self.disposed {
    self.disposed = true
    self.image_tokens = []
    self.image_sources = []
    self.image_events = []
    (self.dispose_fn)()
    match self.native_surface {
      Some(surface) => surface.dispose()
      None => ()
    }
  }
}

///|
pub fn RendererSession::draw_platform_view_pixels(
  self : RendererSession,
  pixels : Bytes,
  src_width : Int,
  src_height : Int,
  src_stride : Int,
  dst_x : Double,
  dst_y : Double,
  dst_width : Double,
  dst_height : Double,
) -> Unit {
  (self.platform_view.draw_platform_view_pixels_fn)(
    pixels, src_width, src_height, src_stride, dst_x, dst_y, dst_width, dst_height,
  )
}

///|
pub fn RendererSession::set_platform_view_draw_fn(
  self : RendererSession,
  draw_fn : (() -> Unit)?,
) -> Unit {
  (self.platform_view.set_platform_view_draw_fn_fn)(draw_fn)
}

///|
fn RendererSession::queue_image_requests(self : RendererSession) -> Unit {
  guard self.image_decoder is Some(decoder) else { return }
  for record in (self.image_records_fn)() {
    if record.status == ImageResourceStatus::ImageLoading &&
      !self.image_sources.any(source => source == record.source) {
      let token = RendererImageLoadToken::new(self.next_image_token)
      self.next_image_token = self.next_image_token + 1L
      self.image_tokens.push(token)
      self.image_sources.push(record.source)
      self.image_events.push(
        RendererEvent::ImageLoadRequested(
          RendererImageLoadRequest::new(
            token~,
            source=record.source,
            image_source=self.image_source,
            decoder~,
          ),
        ),
      )
    }
  }
}

///|
fn RendererSession::take_image_request(
  self : RendererSession,
  token : RendererImageLoadToken,
) -> String? {
  let mut source = None
  let tokens : Array[RendererImageLoadToken] = []
  let sources : Array[String] = []
  for index, current in self.image_tokens {
    if source is None && current == token && index < self.image_sources.length() {
      source = Some(self.image_sources[index])
    } else if index < self.image_sources.length() {
      tokens.push(current)
      sources.push(self.image_sources[index])
    }
  }
  self.image_tokens = tokens
  self.image_sources = sources
  source
}
