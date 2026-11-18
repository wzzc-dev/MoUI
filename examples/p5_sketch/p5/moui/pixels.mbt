///|
/// Host-provided offscreen rasterizer for canvas readback. It receives the
/// current draw commands and surface metrics and must return straight RGBA8
/// pixels. The adapter never depends on a concrete renderer; composition roots
/// install one (Skia in the macOS example, a Canvas2D helper on Web, or a fake
/// in tests).
pub type CanvasRasterizer = (Array[@core.DrawCommand], @core.SurfaceMetrics) -> @p5.Image?

///|
let default_canvas_rasterizer : Ref[CanvasRasterizer?] = Ref(None)

///|
/// Installs the rasterizer inherited by `SketchView`s created after this call.
pub fn set_default_canvas_rasterizer(rasterizer : CanvasRasterizer?) -> Unit {
  default_canvas_rasterizer.val = rasterizer
}

///|
pub fn SketchView::set_rasterizer(
  self : SketchView,
  rasterizer : CanvasRasterizer,
) -> Unit {
  self.rasterizer = Some(rasterizer)
}

///|
pub fn SketchView::clear_rasterizer(self : SketchView) -> Unit {
  self.rasterizer = None
}

///|
fn SketchView::append_canvas_overlay(
  self : SketchView,
  commands : Array[@core.DrawCommand],
) -> Unit {
  match self.overlay_source {
    Some(source) => {
      // Source replaces the destination color *and* alpha, so the committed
      // buffer is exact: erased pixels stay erased and semi-transparent
      // pixels do not double-blend with the history underneath. Backends
      // without a source blend degrade to source-over (documented).
      commands.push(
        @core.PushLayer(
          @core.LayerSpec::new(
            blend_mode=@core.BlendMode::Source,
            offscreen=true,
          ),
        ),
      )
      commands.push(
        @core.DrawImage(
          @core.ImageRun::new(
            source,
            @core.Rect::new(x=0.0, y=0.0, width=self.width, height=self.height),
            fit=@core.ImageFit::Stretch,
          ),
        ),
      )
      commands.push(@core.PopLayer)
    }
    None => ()
  }
}

///|
/// Rasterizes the last painted command list (plus any pixel overlay) through
/// the installed `CanvasRasterizer`. Returns `None` when no rasterizer is
/// installed or the host cannot produce pixels.
pub fn SketchView::capture_image(self : SketchView) -> @p5.Image? {
  match self.rasterizer {
    Some(rasterize) => {
      let commands = self.cached_commands.copy()
      self.append_canvas_overlay(commands)
      rasterize(
        commands,
        @core.SurfaceMetrics::from_logical(
          size=@core.Size::new(width=self.width, height=self.height),
          scale_factor=1.0,
        ),
      )
    }
    None => None
  }
}

///|
/// Captures the canvas and writes it as a PNG. Returns false when the host has
/// no rasterizer or the file cannot be written.
pub fn SketchView::save_canvas(self : SketchView, path : String) -> Bool {
  match self.capture_image() {
    Some(image) => image.save(path)
    None => false
  }
}

///|
/// Captures the canvas into a writable pixel buffer, like p5's `loadPixels`.
/// The buffer is the object returned by `pixels` and modified by `set_pixel`.
pub fn SketchView::load_pixels(self : SketchView) -> @p5.Image? {
  match self.capture_image() {
    Some(image) => {
      self.pixel_buffer = Some(image)
      Some(image)
    }
    None => None
  }
}

///|
/// The current pixel buffer, loading it on first use.
pub fn SketchView::pixels(self : SketchView) -> @p5.Image? {
  match self.pixel_buffer {
    Some(buffer) => Some(buffer)
    None => self.load_pixels()
  }
}

///|
/// Reads a canvas pixel. Returns transparent when no rasterizer is installed.
pub fn SketchView::get_pixel(
  self : SketchView,
  x : Int32,
  y : Int32,
) -> @p5.Color {
  match self.pixels() {
    Some(buffer) => buffer.get(x, y)
    None => @p5.Color::transparent()
  }
}

///|
/// Writes a canvas pixel into the buffer; call `update_pixels` to present it.
/// Returns false when no rasterizer can provide a buffer.
pub fn SketchView::set_pixel(
  self : SketchView,
  x : Int32,
  y : Int32,
  color : @p5.Color,
) -> Bool {
  match self.pixels() {
    Some(buffer) => {
      buffer.set(x, y, color)
      true
    }
    None => false
  }
}

///|
/// Commits the pixel buffer as a canvas overlay, like p5's `updatePixels`.
/// The overlay is drawn after the retained display list every frame, so pixel
/// edits survive later vector frames. It uses source-over compositing: on an
/// opaque canvas the result is exact; on a transparent canvas, overlaying the
/// full buffer can double-blend semi-transparent content.
pub fn SketchView::update_pixels(self : SketchView) -> Bool {
  match self.pixel_buffer {
    Some(buffer) => {
      self.overlay_source = Some(p5_image_source(buffer, None))
      true
    }
    None => false
  }
}

///|
/// Drops the pixel overlay without changing the display list.
pub fn SketchView::clear_pixel_overlay(self : SketchView) -> Unit {
  self.overlay_source = None
}
