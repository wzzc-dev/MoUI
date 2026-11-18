///|
/// Host-provided byte fetcher for `load_image_async`. The host receives the
/// source and a completion callback; it may complete later on its event loop.
/// The p5 core decodes PNG bytes and fills the placeholder image in place.
pub type ImageFetcher = (String, (Bytes?) -> Unit) -> Unit

///|
let default_image_fetcher : Ref[ImageFetcher?] = Ref(None)

///|
/// Installs the fetcher inherited by sketches created after this call. Native
/// app entrypoints use it to route `https:` sources through an async worker
/// without threading a fetcher through every `Sketch::new` call site.
pub fn set_default_image_fetcher(fetcher : ImageFetcher?) -> Unit {
  default_image_fetcher.val = fetcher
}

///|
/// A writable RGBA8 image / graphics buffer.
///
/// `pixels` is straight (non-premultiplied) RGBA in row-major order. Drawing
/// the image goes through `Surface::draw_image`; the MoUI adapter encodes the
/// buffer as a PNG data URI and emits `DrawCommand::DrawImage`, so the same
/// image works with Skia, Sun, and the browser image loader.
pub struct Image {
  priv mut width_ : Int32
  priv mut height_ : Int32
  mut pixels : FixedArray[Byte]
}

///|
pub fn Image::new(
  width : Int32,
  height : Int32,
  fill~ : Color = Color::transparent(),
) -> Image {
  let width = width.max(0)
  let height = height.max(0)
  let image = {
    width_: width,
    height_: height,
    pixels: FixedArray::make(width * height * 4, (0 : Byte)),
  }
  image.fill(fill)
  image
}

///|
/// Builds an image from tightly packed straight RGBA8 pixels. The input is
/// copied, so later mutation of `pixels` does not affect the image.
pub fn Image::from_rgba(
  width : Int32,
  height : Int32,
  pixels : FixedArray[Byte],
) -> Image? {
  if width < 0 || height < 0 || pixels.length() != width * height * 4 {
    None
  } else {
    Some({ width_: width, height_: height, pixels: pixels.copy(), })
  }
}

///|
/// Builds an image from straight RGBA8 rows with a host-supplied stride. This
/// is the entry point for renderer readback, whose rows may carry padding.
pub fn Image::from_rgba_bytes(
  width : Int32,
  height : Int32,
  row_bytes : Int32,
  pixels : Bytes,
) -> Image? {
  if width < 0 ||
    height < 0 ||
    row_bytes < width * 4 ||
    pixels.length() < row_bytes * height {
    None
  } else {
    let out = FixedArray::make(width * height * 4, (0 : Byte))
    for y in 0..<height {
      let source = y * row_bytes
      let destination = y * width * 4
      for offset in 0..<(width * 4) {
        out[destination + offset] = pixels[source + offset]
      }
    }
    Some({ width_: width, height_: height, pixels: out, })
  }
}

///|
pub fn Image::width(self : Image) -> Int32 {
  self.width_
}

///|
pub fn Image::height(self : Image) -> Int32 {
  self.height_
}

///|
/// Replaces this image's dimensions and pixels with another image's. Used by
/// `load_image_async` to fill the placeholder handed to the sketch when the
/// host fetch completes.
fn Image::adopt(self : Image, other : Image) -> Unit {
  self.width_ = other.width_
  self.height_ = other.height_
  self.pixels = other.pixels
}

///|
fn image_byte(value : Double) -> Byte {
  (value.max(0.0).min(1.0) * 255.0 + 0.5).to_int().to_byte()
}

///|
fn image_unit(value : Byte) -> Double {
  value.to_uint().to_double() / 255.0
}

///|
pub fn Image::fill(self : Image, color : Color) -> Unit {
  let r = image_byte(color.r)
  let g = image_byte(color.g)
  let b = image_byte(color.b)
  let a = image_byte(color.a)
  let mut offset = 0
  while offset + 3 < self.pixels.length() {
    self.pixels[offset] = r
    self.pixels[offset + 1] = g
    self.pixels[offset + 2] = b
    self.pixels[offset + 3] = a
    offset = offset + 4
  }
}

///|
/// Returns the pixel at `(x, y)`, or transparent outside the image.
pub fn Image::get(self : Image, x : Int32, y : Int32) -> Color {
  if x < 0 || y < 0 || x >= self.width_ || y >= self.height_ {
    return Color::transparent()
  }
  let offset = (y * self.width_ + x) * 4
  Color::new(
    image_unit(self.pixels[offset]),
    image_unit(self.pixels[offset + 1]),
    image_unit(self.pixels[offset + 2]),
    image_unit(self.pixels[offset + 3]),
  )
}

///|
/// Writes one pixel; out-of-bounds writes are ignored.
pub fn Image::set(self : Image, x : Int32, y : Int32, color : Color) -> Unit {
  if x < 0 || y < 0 || x >= self.width_ || y >= self.height_ {
    return
  }
  let offset = (y * self.width_ + x) * 4
  self.pixels[offset] = image_byte(color.r)
  self.pixels[offset + 1] = image_byte(color.g)
  self.pixels[offset + 2] = image_byte(color.b)
  self.pixels[offset + 3] = image_byte(color.a)
}

///|
/// Pixels are already resident; kept for p5 API compatibility.
pub fn Image::load_pixels(self : Image) -> Unit {
  let _ = self
}

///|
/// Pixels writes are immediate; kept for p5 API compatibility.
pub fn Image::update_pixels(self : Image) -> Unit {
  let _ = self
}

///|
pub fn Image::copy(self : Image) -> Image {
  { width_: self.width_, height_: self.height_, pixels: self.pixels.copy(), }
}

///|
pub fn Image::resize(self : Image, width : Int32, height : Int32) -> Unit {
  self.width_ = width.max(0)
  self.height_ = height.max(0)
  self.pixels = FixedArray::make(self.width_ * self.height_ * 4, (0 : Byte))
}

///|
/// Creates an empty image / graphics buffer, like p5's `createImage` and the
/// pixel-buffer subset of `createGraphics`.
pub fn Sketch::create_image(
  self : Sketch,
  width : Int32,
  height : Int32,
) -> Image {
  let _ = self
  Image::new(width, height)
}

///|
/// Creates a vector graphics buffer. It is a normal `Sketch` with a recording
/// surface: draw with `rect`/`text`/`circle`/..., then pass it to `image()` to
/// replay it onto another sketch.
pub fn Sketch::create_graphics(
  self : Sketch,
  width : Int32,
  height : Int32,
) -> Sketch {
  let recorder = RecordingSurface::new(width.to_double(), height.to_double())
  let sketch = Sketch::new(
    recorder as &Surface,
    width.to_double(),
    height.to_double(),
    file_ports=self.file_ports,
  )
  sketch.graphics = Some(recorder)
  sketch
}

///|
/// Encodes `image` as a PNG and writes it through this sketch's `FilePorts`.
/// Returns false when the ports reject the path. `SketchView::save_canvas`
/// and host `save()` helpers route through here so image saving never reaches
/// for a concrete filesystem.
pub fn Sketch::save_image(self : Sketch, image : Image, path : String) -> Bool {
  self.file_ports.save(path, image.to_png_bytes())
}

///|
/// Something `Sketch::image` can draw: a pixel `Image` or a graphics sketch.
pub(open) trait ImageSource {
  fn image_size(Self) -> (Double, Double)
  fn draw_as_image(Self, Sketch, Double, Double, Double, Double) -> Unit
}

///|
pub impl ImageSource for Image with fn image_size(self) {
  (self.width().to_double(), self.height().to_double())
}

///|
pub impl ImageSource for Image with fn draw_as_image(
  self,
  target,
  x,
  y,
  width,
  height,
) {
  target.surface.set_transform(target.style.matrix)
  target.surface.draw_image(self, x, y, width, height, 1.0, target.style.tint)
}

///|
pub impl ImageSource for Sketch with fn image_size(self) {
  (self.width, self.height)
}

///|
pub impl ImageSource for Sketch with fn draw_as_image(
  self,
  target,
  x,
  y,
  width,
  height,
) {
  match self.graphics {
    Some(graphics) => target.replay_graphics(graphics, x, y, width, height)
    None => ()
  }
}

///|
fn Sketch::replay_graphics(
  self : Sketch,
  graphics : RecordingSurface,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  let scale_x = if graphics.width > 0.0 { width / graphics.width } else { 1.0 }
  let scale_y = if graphics.height > 0.0 {
    height / graphics.height
  } else {
    1.0
  }
  let base = self.style.matrix.compose(
    Matrix::translation(x, y).compose(Matrix::scaling(scale_x, scale_y)),
  )
  self.surface.save()
  self.surface.set_transform(base)
  let mut open_clips = 0
  for op in graphics.ops {
    self.surface.set_transform(base.compose(op.transform))
    self.surface.set_blend_mode(op.blend)
    match op.kind {
      FillPath(path, color) => self.surface.fill_path(path, color)
      StrokePath(path, color, stroke_width, cap, join) =>
        self.surface.stroke_path(path, color, stroke_width, cap, join)
      FillRect(fx, fy, fw, fh, color) =>
        self.surface.fill_rect(fx, fy, fw, fh, color)
      FillRoundRect(fx, fy, fw, fh, radius, color) =>
        self.surface.fill_rounded_rect(fx, fy, fw, fh, radius, color)
      StrokeRoundRect(fx, fy, fw, fh, radius, color, stroke_width) =>
        self.surface.stroke_rounded_rect(
          fx, fy, fw, fh, radius, color, stroke_width,
        )
      DrawImage(image, ix, iy, iw, ih, opacity, tint) =>
        self.surface.draw_image(image, ix, iy, iw, ih, opacity, tint)
      FillText(
        text,
        tx,
        ty,
        color,
        stroke,
        stroke_width,
        font,
        align_h,
        align_v
      ) =>
        self.surface.fill_text(
          text, tx, ty, color, stroke, stroke_width, font, align_h, align_v,
        )
      ClipPath(path) => {
        self.surface.clip_path(path)
        open_clips = open_clips + 1
      }
      ClipEnd =>
        if open_clips > 0 {
          self.surface.clip_end()
          open_clips = open_clips - 1
        }
    }
  }
  while open_clips > 0 {
    self.surface.clip_end()
    open_clips = open_clips - 1
  }
  self.surface.restore()
}

///|
/// Draws an image or graphics buffer at `(x, y)`. Width/height default to the
/// source size.
pub fn[T : ImageSource] Sketch::image(
  self : Sketch,
  source : T,
  x : Double,
  y : Double,
  width~ : Double = 0.0,
  height~ : Double = 0.0,
) -> Unit {
  let (source_width, source_height) = source.image_size()
  let width = if width > 0.0 { width } else { source_width }
  let height = if height > 0.0 { height } else { source_height }
  source.draw_as_image(self, x, y, width, height)
}

///|
pub extend Image with ImageSource::{draw_as_image, image_size}

///|
pub extend Sketch with ImageSource::{draw_as_image, image_size}
