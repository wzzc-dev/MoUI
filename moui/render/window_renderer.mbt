///|
pub struct HostRendererImageCapability {
  priv image_resources_fn : () -> Array[ImageResourceRecord]
  priv image_resource_snapshot_fn : () -> ImageResourceSnapshot
  priv apply_image_resource_load_completion_fn : (ImageResourceLoadCompletion) -> ImageResourceSnapshot
  priv set_image_resource_change_callback_fn : (
    ((ImageResourceSnapshot) -> Unit)?,
  ) -> Unit
}

///|
pub struct HostRendererPlatformViewCapability {
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
pub struct HostRendererGpuRecoveryCapability {
  priv inject_context_loss_fn : () -> Unit
  priv gpu_recovery_count_fn : () -> Int
  priv gpu_fallback_active_fn : () -> Bool
}

///|
pub struct WindowRenderer {
  priv resize_fn : (@core.SurfaceMetrics) -> Unit
  priv render_fn : (Array[@core.DrawCommand]) -> Unit
  priv render_frame_fn : (@core.DrawFrame) -> RenderFrameResult
  priv drain_present_completions_fn : () -> Array[RenderPresentCompletion]
  priv text_system_fn : () -> @core.TextSystem
  priv image : HostRendererImageCapability
  priv present_count_fn : () -> Int
  priv dispose_fn : () -> Unit
  priv mut disposed : Bool
  priv platform_view : HostRendererPlatformViewCapability
  priv gpu_recovery : HostRendererGpuRecoveryCapability
}

///|
pub fn HostRendererImageCapability::new(
  image_resources? : () -> Array[ImageResourceRecord] = () => [],
  image_resource_snapshot? : (() -> ImageResourceSnapshot)? = None,
  apply_image_resource_load_completion? : ((ImageResourceLoadCompletion) -> ImageResourceSnapshot)? = None,
  set_image_resource_change_callback? : (((ImageResourceSnapshot) -> Unit)?) -> Unit = _callback => {
    ()
  },
) -> HostRendererImageCapability {
  let image_resource_snapshot = match image_resource_snapshot {
    Some(snapshot) => snapshot
    None => () => ImageResourceSnapshot::from_records(image_resources())
  }
  let apply_image_resource_load_completion = match
    apply_image_resource_load_completion {
    Some(apply) => apply
    None => _completion => image_resource_snapshot()
  }
  {
    image_resources_fn: image_resources,
    image_resource_snapshot_fn: image_resource_snapshot,
    apply_image_resource_load_completion_fn: apply_image_resource_load_completion,
    set_image_resource_change_callback_fn: set_image_resource_change_callback,
  }
}

///|
pub fn HostRendererPlatformViewCapability::new(
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
) -> HostRendererPlatformViewCapability {
  {
    draw_platform_view_pixels_fn: draw_platform_view_pixels,
    set_platform_view_draw_fn_fn: set_platform_view_draw_fn,
  }
}

///|
pub fn HostRendererGpuRecoveryCapability::new(
  inject_context_loss? : () -> Unit = () => (),
  gpu_recovery_count? : () -> Int = () => 0,
  gpu_fallback_active? : () -> Bool = () => false,
) -> HostRendererGpuRecoveryCapability {
  {
    inject_context_loss_fn: inject_context_loss,
    gpu_recovery_count_fn: gpu_recovery_count,
    gpu_fallback_active_fn: gpu_fallback_active,
  }
}

///|
pub fn WindowRenderer::new(
  resize~ : (@core.SurfaceMetrics) -> Unit,
  render~ : (Array[@core.DrawCommand]) -> Unit,
  render_frame? : ((@core.DrawFrame) -> RenderFrameResult)? = None,
  drain_present_completions? : (() -> Array[RenderPresentCompletion])? = None,
  text_system~ : () -> @core.TextSystem,
  present_count? : () -> Int = () => 0,
  dispose? : () -> Unit = () => (),
  image? : HostRendererImageCapability = HostRendererImageCapability::new(),
  platform_view? : HostRendererPlatformViewCapability = HostRendererPlatformViewCapability::new(),
  gpu_recovery? : HostRendererGpuRecoveryCapability = HostRendererGpuRecoveryCapability::new(),
) -> WindowRenderer {
  let render_frame_fn = match render_frame {
    Some(render_frame) => render_frame
    None =>
      frame => {
        let commands : Array[@core.DrawCommand] = [
          @core.DrawCommand::Clear(frame.clear_color),
        ]
        commands.append(frame.commands)
        render(commands)
        RenderFrameResult::new()
      }
  }
  let drain_present_completions_fn = match drain_present_completions {
    Some(drain) => drain
    None => () => []
  }
  {
    resize_fn: resize,
    render_fn: render,
    render_frame_fn,
    drain_present_completions_fn,
    text_system_fn: text_system,
    image,
    present_count_fn: present_count,
    dispose_fn: dispose,
    disposed: false,
    platform_view,
    gpu_recovery,
  }
}

///|
pub fn WindowRenderer::resize(
  self : WindowRenderer,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  (self.resize_fn)(metrics)
}

///|
pub fn WindowRenderer::render(
  self : WindowRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit {
  (self.render_fn)(commands)
}

///|
pub fn WindowRenderer::render_frame(
  self : WindowRenderer,
  frame : @core.DrawFrame,
) -> RenderFrameResult {
  (self.render_frame_fn)(frame)
}

///|
/// Drain asynchronous renderer-worker completions. Synchronous raster
/// providers return an empty array; GPU workers return one record per frame
/// that reached present, was dropped, or triggered raster fallback.
pub fn WindowRenderer::drain_present_completions(
  self : WindowRenderer,
) -> Array[RenderPresentCompletion] {
  (self.drain_present_completions_fn)()
}

///|
/// Report whether a renderer-worker completion proves a window present.
pub fn render_present_completion_is_presented(
  completion : RenderPresentCompletion,
) -> Bool {
  completion.status() is RenderPresentStatus::Presented
}

///|
/// Report whether any drained completion proves a window present.
pub fn render_present_completions_have_presented(
  completions : Array[RenderPresentCompletion],
) -> Bool {
  completions.any(render_present_completion_is_presented)
}

///|
/// Report whether a queued frame reached any terminal outcome. `Recorded` is
/// an internal handoff signal and does not complete a window presentation.
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
pub fn WindowRenderer::text_system(self : WindowRenderer) -> @core.TextSystem {
  (self.text_system_fn)()
}

///|
pub fn WindowRenderer::image_resources(
  self : WindowRenderer,
) -> Array[ImageResourceRecord] {
  (self.image.image_resources_fn)()
}

///|
pub fn WindowRenderer::image_resource_snapshot(
  self : WindowRenderer,
) -> ImageResourceSnapshot {
  (self.image.image_resource_snapshot_fn)()
}

///|
pub fn WindowRenderer::apply_image_resource_load_completion(
  self : WindowRenderer,
  completion : ImageResourceLoadCompletion,
) -> ImageResourceSnapshot {
  (self.image.apply_image_resource_load_completion_fn)(completion)
}

///|
pub fn WindowRenderer::set_image_resource_change_callback(
  self : WindowRenderer,
  callback : ((ImageResourceSnapshot) -> Unit)?,
) -> Unit {
  (self.image.set_image_resource_change_callback_fn)(callback)
}

///|
pub fn WindowRenderer::present_count(self : WindowRenderer) -> Int {
  (self.present_count_fn)()
}

///|
/// Inject a synthetic GPU context-loss control for promotion harnesses.
pub fn WindowRenderer::inject_context_loss(self : WindowRenderer) -> Unit {
  (self.gpu_recovery.inject_context_loss_fn)()
}

///|
pub fn WindowRenderer::gpu_recovery_count(self : WindowRenderer) -> Int {
  (self.gpu_recovery.gpu_recovery_count_fn)()
}

///|
pub fn WindowRenderer::gpu_fallback_active(self : WindowRenderer) -> Bool {
  (self.gpu_recovery.gpu_fallback_active_fn)()
}

///|
pub fn WindowRenderer::dispose(self : WindowRenderer) -> Unit {
  if !self.disposed {
    self.disposed = true
    (self.dispose_fn)()
  }
}

///|
/// Draw platform view pixels onto the renderer surface (e.g., offscreen webview)
pub fn WindowRenderer::draw_platform_view_pixels(
  self : WindowRenderer,
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

///| Set a callback to draw platform view content after command rendering but before flush.

///|
/// Used by Linux to composite offscreen webview pixels into the Skia surface.
pub fn WindowRenderer::set_platform_view_draw_fn(
  self : WindowRenderer,
  draw_fn : (() -> Unit)?,
) -> Unit {
  (self.platform_view.set_platform_view_draw_fn_fn)(draw_fn)
}
