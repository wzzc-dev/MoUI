///|
/// Skia-backed `CanvasRasterizer` for p5 canvas readback.
///
/// The live window may present through a GPU surface, so this renders the
/// current p5 command list into a fresh offscreen CPU Skia surface instead of
/// reading the window drawable. That keeps `save_canvas`, `load_pixels`, and
/// `get_pixel` independent of the active presentation route.
///
/// `SkiaCanvasRaster` reuses one renderer/surface pair across frames so
/// offline frame-sequence capture does not pay Skia surface creation per
/// frame (and can afford a 2x capture scale).

///|
fn frame_to_image(frame : @render_skia.SkiaPixelFrame) -> @p5.Image? {
  let width = frame.width()
  let height = frame.height()
  let row_bytes = frame.row_bytes()
  let source = frame.pixels()
  let out = FixedArray::make(width * height * 4, (0 : Byte))
  for y in 0..<height {
    for x in 0..<width {
      let from = y * row_bytes + x * 4
      let to = (y * width + x) * 4
      let alpha = source[from + 3].to_uint().reinterpret_as_int()
      let unpremultiply = fn(channel : Byte) {
        if alpha == 0 {
          0
        } else {
          let value = channel.to_uint().reinterpret_as_int()
          ((value * 255 + alpha / 2) / alpha).min(255)
        }
      }
      out[to] = unpremultiply(source[from]).to_byte()
      out[to + 1] = unpremultiply(source[from + 1]).to_byte()
      out[to + 2] = unpremultiply(source[from + 2]).to_byte()
      out[to + 3] = alpha.to_byte()
    }
  }
  @p5.Image::from_rgba(width, height, out)
}

///|
/// A reusable offscreen Skia renderer bound to one capture size. Call
/// `capture` once per frame; the surface is reused, so every command list
/// must repaint its full canvas (the p5 frame stream starts with an opaque
/// background fill, which satisfies that).
pub struct SkiaCanvasRaster {
  priv renderer : @render_skia.SkiaRasterRenderer
  priv captured : Ref[@render_skia.SkiaPixelFrame?]
}

///|
pub fn SkiaCanvasRaster::new(
  metrics : @core.SurfaceMetrics,
) -> SkiaCanvasRaster? {
  let captured : Ref[@render_skia.SkiaPixelFrame?] = Ref(None)
  let target = @render_skia.SkiaPresentTarget::new(
    description="p5-canvas-readback",
    present=frame => {
      captured.val = Some(frame)
      true
    },
  )
  let renderer = try
    @render_skia.create_with_present_target(metrics, target)
  catch {
    _ => return None
  } noraise {
    renderer => renderer
  }
  Some({ renderer, captured, })
}

///|
pub fn SkiaCanvasRaster::capture(
  self : SkiaCanvasRaster,
  commands : Array[@core.DrawCommand],
) -> @p5.Image? {
  self.captured.val = None
  ignore(
    try self.renderer.render(commands) catch {
      _ => return None
    } noraise {
      _ => ()
    },
  )
  match self.captured.val {
    Some(frame) => frame_to_image(frame)
    None => None
  }
}

///|
/// The text system this session's renderer uses for shaping. Offline capture
/// must bind the same system to the sketch so `measure_text` matches the
/// glyph runs drawn into the surface.
pub fn SkiaCanvasRaster::text_system(
  self : SkiaCanvasRaster,
) -> @core.TextSystem {
  self.renderer.text_system()
}

///|
/// One-shot rasterization: creates a session, captures, and drops it.
pub fn rasterize(
  commands : Array[@core.DrawCommand],
  metrics : @core.SurfaceMetrics,
) -> @p5.Image? {
  match SkiaCanvasRaster::new(metrics) {
    Some(session) => session.capture(commands)
    None => None
  }
}

///|
/// Installs the Skia rasterizer as the default for sketches created afterwards.
pub fn install() -> Unit {
  @p5m.set_default_canvas_rasterizer(Some(rasterize))
}
