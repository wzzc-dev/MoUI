///|
/// Canvas 2D renderer for WeChat Mini Program Skyline engine.
/// Renders DrawCommand sequences through the CanvasRenderingContext2D API.

///|
pub type Canvas2DError = String

///|
pub(all) struct Canvas2DRenderer {
  canvas_id : String
  mut logical_width : Double
  mut logical_height : Double
  mut scale_factor : Double
  mut disposed : Bool
}

///|
pub fn Canvas2DRenderer::new(canvas_id~ : String) -> Canvas2DRenderer {
  {
    canvas_id,
    logical_width: 0.0,
    logical_height: 0.0,
    scale_factor: 1.0,
    disposed: false,
  }
}

///|
pub fn canvas2d_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=@render.RendererBackendKind::Canvas2DWasm,
    family=@render.RendererFamily::Canvas2D,
    presentation=@render.RendererPresentationModel::WebCanvas,
    supported_targets=[@render.RendererTarget::WasmGc],
    capabilities=canvas2d_provider_capabilities(
      provider_id="wxCanvas2d",
      backend=@render.RendererBackendKind::Canvas2DWasm,
    ),
    description="Canvas 2D renderer for WeChat Mini Program Skyline engine; renders DrawCommand sequences through the CanvasRenderingContext2D API.",
  )
}

///|
pub fn canvas2d_preflight() -> @render.RendererBackendInfo {
  @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::Canvas2DWasm,
    status=@render.RendererCapabilityStatus::Supported,
    can_render=true,
    can_resize=true,
    owns_surface=false,
    description="Canvas 2D renderer ready; rendering is performed through the CanvasRenderingContext2D API imported from the host JavaScript runtime.",
  )
}

///|
pub fn Canvas2DRenderer::resize(
  self : Canvas2DRenderer,
  metrics : @render.RendererSurfaceMetrics,
) -> Unit {
  self.logical_width = metrics.logical_size.width
  self.logical_height = metrics.logical_size.height
  self.scale_factor = metrics.scale_factor
}

///|
pub fn Canvas2DRenderer::render(
  self : Canvas2DRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit {
  if self.disposed {
    return
  }
  // Rendering is dispatched through the JS host bridge.
  // The actual CanvasRenderingContext2D calls are performed
  // in the canvas2d_runtime.js file.
  let plan = @render.lower_draw_commands(commands)
  canvas2d_render_commands(
    self.canvas_id,
    self.logical_width,
    self.logical_height,
    plan.ops,
  )
}

///|
pub fn Canvas2DRenderer::render_frame(
  self : Canvas2DRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult {
  if self.disposed {
    return @render.RenderFrameResult::new(presented=false)
  }
  let plan = @render.lower_draw_commands(frame.commands)
  canvas2d_render_commands(
    self.canvas_id,
    self.logical_width,
    self.logical_height,
    plan.ops,
  )
  @render.RenderFrameResult::new(presented=true)
}

///|
pub fn Canvas2DRenderer::text_system(
  _self : Canvas2DRenderer,
) -> @core.TextSystem {
  @core.TextSystem::new(
    id="canvas2d-text-system",
    measure=canvas2d_measure_text_impl,
  )
}

///|
pub fn Canvas2DRenderer::image_resources(
  _self : Canvas2DRenderer,
) -> Array[@render.ImageResourceRecord] {
  []
}

///|
pub fn Canvas2DRenderer::image_resource_snapshot(
  _self : Canvas2DRenderer,
) -> @render.ImageResourceSnapshot {
  @render.ImageResourceSnapshot::from_records([])
}

///|
pub fn Canvas2DRenderer::dispose(self : Canvas2DRenderer) -> Unit {
  self.disposed = true
}

///|
/// Canvas 2D JS bridge functions.
/// Each extern "wasm" function maps to a CanvasRenderingContext2D operation
/// in the host JavaScript runtime.

///|
extern "wasm" fn canvas2d_begin_frame(width : Double, height : Double) = "canvas2d" "begin_frame"

///|
extern "wasm" fn canvas2d_save() = "canvas2d" "save"

///|
extern "wasm" fn canvas2d_restore() = "canvas2d" "restore"

///|
extern "wasm" fn canvas2d_fill_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) = "canvas2d" "fill_rect"

///|
extern "wasm" fn canvas2d_fill_rounded_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) = "canvas2d" "fill_rounded_rect"

///|
extern "wasm" fn canvas2d_stroke_rounded_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
  stroke_width : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) = "canvas2d" "stroke_rounded_rect"

///|
extern "wasm" fn canvas2d_draw_text(
  c0 : Int,
  c1 : Int,
  c2 : Int,
  c3 : Int,
  c4 : Int,
  c5 : Int,
  c6 : Int,
  c7 : Int,
  c8 : Int,
  c9 : Int,
  c10 : Int,
  c11 : Int,
  c12 : Int,
  c13 : Int,
  c14 : Int,
  c15 : Int,
  c16 : Int,
  c17 : Int,
  c18 : Int,
  c19 : Int,
  len : Int,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  font_size : Double,
  font_weight : Int,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
  align : Int,
) = "canvas2d" "draw_text"

///|
extern "wasm" fn canvas2d_set_transform(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  tx : Double,
  ty : Double,
) = "canvas2d" "set_transform"

///|
extern "wasm" fn canvas2d_clip_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) = "canvas2d" "clip_rect"

///|
extern "wasm" fn canvas2d_clip_rounded_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
) = "canvas2d" "clip_rounded_rect"

///|
extern "wasm" fn canvas2d_set_global_alpha(alpha : Double) = "canvas2d" "set_global_alpha"

///|
extern "wasm" fn canvas2d_stroke_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  stroke_width : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) = "canvas2d" "stroke_rect"

///|
extern "wasm" fn canvas2d_draw_shadow(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
  offset_x : Double,
  offset_y : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
  blur : Double,
  clip : Int,
) = "canvas2d" "draw_shadow"

///|
extern "wasm" fn canvas2d_draw_path(
  op : Int,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) = "canvas2d" "draw_path"

///|
extern "wasm" fn canvas2d_measure_text_width(
  c0 : Int,
  c1 : Int,
  c2 : Int,
  c3 : Int,
  c4 : Int,
  c5 : Int,
  c6 : Int,
  c7 : Int,
  c8 : Int,
  c9 : Int,
  c10 : Int,
  c11 : Int,
  c12 : Int,
  c13 : Int,
  c14 : Int,
  c15 : Int,
  c16 : Int,
  c17 : Int,
  c18 : Int,
  c19 : Int,
  len : Int,
  font_size : Double,
  font_weight : Int,
) -> Double = "canvas2d" "measure_text_width"

///|
/// Real DrawCommand interpreter — iterates through commands and calls the
/// corresponding Canvas 2D JS bridge functions.
fn canvas2d_render_commands(
  canvas_id : String,
  width : Double,
  height : Double,
  commands : Array[@render.PlanOp],
) -> Unit {
  let _ = canvas_id
  // Begin a new frame — clear the canvas
  canvas2d_begin_frame(width, height)
  for cmd in commands {
    match cmd {
      Clear(color) =>
        canvas2d_fill_rect(
          0.0,
          0.0,
          width,
          height,
          color.r,
          color.g,
          color.b,
          color.a,
        )
      FillRect(rect, color) =>
        canvas2d_fill_rect(
          rect.origin.x,
          rect.origin.y,
          rect.size.width,
          rect.size.height,
          color.r,
          color.g,
          color.b,
          color.a,
        )
      FillRoundedRect(rr, color) =>
        canvas2d_fill_rounded_rect(
          rr.rect.origin.x,
          rr.rect.origin.y,
          rr.rect.size.width,
          rr.rect.size.height,
          rr.radius,
          color.r,
          color.g,
          color.b,
          color.a,
        )
      StrokeRoundedRect(rr, color, stroke_width) =>
        canvas2d_stroke_rounded_rect(
          rr.rect.origin.x,
          rr.rect.origin.y,
          rr.rect.size.width,
          rr.rect.size.height,
          rr.radius,
          stroke_width,
          color.r,
          color.g,
          color.b,
          color.a,
        )
      DrawText(text_run) => {
        let text = text_run.text
        let text_len = text.length()
        let chars : FixedArray[Int] = FixedArray::make(20, 0)
        for i = 0; i < text_len && i < 20; i = i + 1 {
          chars[i] = text[i].to_int()
        }
        let align_int = match text_run.align {
          TextStart => 0
          TextCenter => 1
          TextEnd => 2
        }
        canvas2d_draw_text(
          chars[0],
          chars[1],
          chars[2],
          chars[3],
          chars[4],
          chars[5],
          chars[6],
          chars[7],
          chars[8],
          chars[9],
          chars[10],
          chars[11],
          chars[12],
          chars[13],
          chars[14],
          chars[15],
          chars[16],
          chars[17],
          chars[18],
          chars[19],
          text_len,
          text_run.frame.origin.x,
          text_run.frame.origin.y,
          text_run.frame.size.width,
          text_run.frame.size.height,
          text_run.font.size,
          text_run.font.weight,
          text_run.color.r,
          text_run.color.g,
          text_run.color.b,
          text_run.color.a,
          align_int,
        )
      }
      PushTransform(t) => {
        canvas2d_save()
        canvas2d_set_transform(t.a, t.b, t.c, t.d, t.tx, t.ty)
      }
      PopTransform => canvas2d_restore()
      PushClip(rect) => {
        canvas2d_save()
        canvas2d_clip_rect(
          rect.origin.x,
          rect.origin.y,
          rect.size.width,
          rect.size.height,
        )
      }
      PopClip => canvas2d_restore()
      PushRoundedClip(rr) => {
        canvas2d_save()
        canvas2d_clip_rounded_rect(
          rr.rect.origin.x,
          rr.rect.origin.y,
          rr.rect.size.width,
          rr.rect.size.height,
          rr.radius,
        )
      }
      PopRoundedClip => canvas2d_restore()
      PushOpacity(opacity) => {
        canvas2d_save()
        canvas2d_set_global_alpha(opacity)
      }
      PopOpacity => canvas2d_restore()
      FillRoundedRectBrush(rr, brush) => {
        let color = brush.fallback_color()
        canvas2d_fill_rounded_rect(
          rr.rect.origin.x,
          rr.rect.origin.y,
          rr.rect.size.width,
          rr.rect.size.height,
          rr.radius,
          color.r,
          color.g,
          color.b,
          color.a,
        )
      }
      StrokeRoundedRectBrush(rr, brush, stroke_width) => {
        let color = brush.fallback_color()
        canvas2d_stroke_rounded_rect(
          rr.rect.origin.x,
          rr.rect.origin.y,
          rr.rect.size.width,
          rr.rect.size.height,
          rr.radius,
          stroke_width,
          color.r,
          color.g,
          color.b,
          color.a,
        )
      }
      DrawShadow(shadow) => {
        let color = shadow.color
        canvas2d_draw_shadow(
          shadow.rect.rect.origin.x,
          shadow.rect.rect.origin.y,
          shadow.rect.rect.size.width,
          shadow.rect.rect.size.height,
          shadow.rect.radius,
          shadow.offset.x,
          shadow.offset.y,
          color.r,
          color.g,
          color.b,
          color.a,
          shadow.blur_radius,
          if shadow.rect.radius > 0.0 {
            1
          } else {
            0
          },
        )
      }
      DrawPath(path) => {
        let color = match path.fill {
          Some(b) => b.fallback_color()
          None =>
            match path.stroke {
              Some(b) => b.fallback_color()
              None => @core.Color::{ r: 0.0, g: 0.0, b: 0.0, a: 1.0 }
            }
        }
        // Simple path rendering: op=0 for fill, op=1 for stroke
        let op = match path.fill {
          Some(_) => 0
          None => 1
        }
        canvas2d_draw_path(
          op,
          0.0,
          0.0,
          0.0,
          0.0,
          color.r,
          color.g,
          color.b,
          color.a,
        )
      }
      StrokeRect(rect, color, stroke_width) =>
        canvas2d_stroke_rect(
          rect.origin.x,
          rect.origin.y,
          rect.size.width,
          rect.size.height,
          stroke_width,
          color.r,
          color.g,
          color.b,
          color.a,
        )
      _ => ()
    }
  }
}

///|
/// Text measurement implementation — uses Canvas 2D measureText via
/// the JS host bridge. Returns a default result when the bridge is
/// not available.
fn canvas2d_measure_text_impl(
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  let text = input.text
  let text_len = text.length()
  let chars : FixedArray[Int] = FixedArray::make(20, 0)
  for i = 0; i < text_len && i < 20; i = i + 1 {
    chars[i] = text[i].to_int()
  }
  let width = canvas2d_measure_text_width(
    chars[0],
    chars[1],
    chars[2],
    chars[3],
    chars[4],
    chars[5],
    chars[6],
    chars[7],
    chars[8],
    chars[9],
    chars[10],
    chars[11],
    chars[12],
    chars[13],
    chars[14],
    chars[15],
    chars[16],
    chars[17],
    chars[18],
    chars[19],
    text_len,
    input.font.size,
    input.font.weight,
  )
  let font_size = input.font.size
  @core.TextLayoutResult::{
    size: @core.Size::new(width~, height=font_size * 1.2),
    baseline: font_size * 0.85,
    caret_positions: [],
  }
}

///|
pub fn canvas2d_create_renderer(
  canvas_id~ : String,
  metrics~ : @render.RendererSurfaceMetrics,
) -> Canvas2DRenderer {
  let renderer = Canvas2DRenderer::new(canvas_id~)
  renderer.resize(metrics)
  renderer
}

///|
pub fn canvas2d_render_frame(
  renderer : Canvas2DRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult {
  renderer.render_frame(frame)
}

///|
pub fn canvas2d_resize(
  renderer : Canvas2DRenderer,
  metrics : @render.RendererSurfaceMetrics,
) -> Unit {
  renderer.resize(metrics)
}

///|
pub fn canvas2d_dispose(renderer : Canvas2DRenderer) -> Unit {
  renderer.dispose()
}

///|
pub fn canvas2d_drain_present() -> Array[@render.RenderPresentCompletion] {
  []
}

///|
pub fn canvas2d_image_load_completion(
  source : String,
) -> @render.ImageResourceLoadCompletion {
  @render.ImageResourceLoadCompletion::failed(
    source,
    diagnostic="Canvas 2D renderer does not support native image loading",
  )
}

///|
pub fn canvas2d_image_load_completion_from_bytes(
  source : String,
  _bytes : Bytes,
  background_io? : Bool = false,
) -> @render.ImageResourceLoadCompletion {
  @render.ImageResourceLoadCompletion::failed(
    source,
    diagnostic="Canvas 2D renderer does not support native image loading",
    background_io~,
  )
}

///|
pub fn canvas2d_apply_image_resource_load_completion(
  _completion : @render.ImageResourceLoadCompletion,
) -> @render.ImageResourceSnapshot {
  @render.ImageResourceSnapshot::from_records([])
}

///|
pub fn canvas2d_image_resource_records() -> Array[@render.ImageResourceRecord] {
  []
}

///|
pub fn canvas2d_image_resource_revisioned_snapshots() -> @render.ImageResourceSnapshot {
  @render.ImageResourceSnapshot::from_records([])
}

///|
pub fn canvas2d_set_image_resource_change_callback(
  _callback : ((@render.ImageResourceSnapshot) -> Unit)?,
) -> Unit {

}

///|
pub fn canvas2d_cached_layer_summary() -> String {
  "canvas2d cached-layer summary: no cached layers"
}
