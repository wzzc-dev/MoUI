///|
/// Drawing backend protocol.
///
/// The sketch computes its transform stack and style state, then asks the
/// surface to paint local-space paths, text, and clipped regions. Implemented
/// by `p5/moui` (`MoUISurface`), `Recorder` (tests), and `NullSurface` (before
/// the first frame is bound).

///|
pub(open) trait Surface {
  fn set_transform(Self, Matrix) -> Unit
  fn save(Self) -> Unit
  fn restore(Self) -> Unit
  fn fill_path(Self, Path, Color) -> Unit
  fn stroke_path(Self, Path, Color, Double, StrokeCap, StrokeJoin) -> Unit
  fn fill_rect(Self, Double, Double, Double, Double, Color) -> Unit
  /// Uniform-radius rounded rectangle. This is the cheap primitive behind
  /// circles and pills on backends with SDF/quads (web, Skia rounded rects);
  /// `fill_path` remains the general fallback.
  fn fill_rounded_rect(Self, Double, Double, Double, Double, Double, Color) -> Unit
  /// Uniform-radius rounded-rect outline, `stroke width` last.
  fn stroke_rounded_rect(
    Self,
    Double,
    Double,
    Double,
    Double,
    Double,
    Color,
    Double,
  ) -> Unit
  fn clear_rect(Self, Double, Double, Double, Double) -> Unit
  fn draw_image(Self, Image, Double, Double, Double, Double, Double, Color?) -> Unit
  fn clip_path(Self, Path) -> Unit
  fn clip_end(Self) -> Unit
  /// Fill color, optional outline stroke color, stroke width.
  fn fill_text(
    Self,
    String,
    Double,
    Double,
    Color,
    Color?,
    Double,
    FontSpec,
    HAlign,
    VAlign,
  ) -> Unit
  fn measure_width(Self, String, FontSpec) -> Double
  fn text_metrics(Self, FontSpec) -> TextMetrics
  fn set_blend_mode(Self, BlendMode) -> Unit
  fn set_smoothing(Self, Bool) -> Unit
}

///|
/// A do-nothing surface used while a sketch is not bound to a frame.
pub(all) struct NullSurface {
  marker : Bool
}

///|
pub fn NullSurface::new() -> NullSurface {
  { marker: true, }
}

///|
pub fn NullSurface::is_null(self : NullSurface) -> Bool {
  self.marker
}

///|
fn surface_metrics_fallback(font : FontSpec) -> TextMetrics {
  TextMetrics::new(
    width=0.0,
    height=font.size * 1.2,
    ascent=font.size * 0.8,
    descent=font.size * 0.2,
  )
}

///|
pub impl Surface for NullSurface with fn set_transform(_, _) {

}

///|
pub impl Surface for NullSurface with fn save(_) {

}

///|
pub impl Surface for NullSurface with fn restore(_) {

}

///|
pub impl Surface for NullSurface with fn fill_path(_, _, _) {

}

///|
pub impl Surface for NullSurface with fn stroke_path(_, _, _, _, _, _) {

}

///|
pub impl Surface for NullSurface with fn fill_rect(_, _, _, _, _, _) {

}

///|
pub impl Surface for NullSurface with fn fill_rounded_rect(_, _, _, _, _, _, _) {

}

///|
pub impl Surface for NullSurface with fn stroke_rounded_rect(
  _,
  _,
  _,
  _,
  _,
  _,
  _,
  _,
) {

}

///|
pub impl Surface for NullSurface with fn clear_rect(_, _, _, _, _) {

}

///|
pub impl Surface for NullSurface with fn draw_image(_, _, _, _, _, _, _, _) {

}

///|
pub impl Surface for NullSurface with fn clip_path(_, _) {

}

///|
pub impl Surface for NullSurface with fn clip_end(_) {

}

///|
pub impl Surface for NullSurface with fn fill_text(_, _, _, _, _, _, _, _, _, _) {

}

///|
pub impl Surface for NullSurface with fn measure_width(_, text, font) {
  text.length().to_double() * font.size * 0.5
}

///|
pub impl Surface for NullSurface with fn text_metrics(_, font) {
  surface_metrics_fallback(font)
}

///|
pub impl Surface for NullSurface with fn set_blend_mode(_, _) {

}

///|
pub impl Surface for NullSurface with fn set_smoothing(_, _) {

}

///|
fn align_h_text(value : HAlign) -> String {
  match value {
    Left => "left"
    HCenter => "center"
    Right => "right"
  }
}

///|
fn align_v_text(value : VAlign) -> String {
  match value {
    Top => "top"
    VCenter => "middle"
    Bottom => "bottom"
    Baseline => "baseline"
  }
}

///|
fn blend_text(value : BlendMode) -> String {
  match value {
    Blend => "blend"
    Multiply => "multiply"
    Screen => "screen"
    Overlay => "overlay"
    Darken => "darken"
    Lighten => "lighten"
    Add => "add"
    Difference => "difference"
    Exclusion => "exclusion"
    HardLight => "hard-light"
    SoftLight => "soft-light"
    Dodge => "dodge"
    Burn => "burn"
  }
}

///|
fn number(value : Double) -> String {
  let rounded = round(value, decimals=3)
  if rounded == 0.0 {
    "0"
  } else {
    rounded.to_string()
  }
}

///|
fn path_text(path : Path) -> String {
  let parts : Array[String] = []
  for command in path.commands {
    match command {
      MoveTo(x, y) => parts.push("M\{number(x)},\{number(y)}")
      LineTo(x, y) => parts.push("L\{number(x)},\{number(y)}")
      QuadTo(cx, cy, x, y) =>
        parts.push("Q\{number(cx)},\{number(cy)} \{number(x)},\{number(y)}")
      CubicTo(c1x, c1y, c2x, c2y, x, y) =>
        parts.push(
          "C\{number(c1x)},\{number(c1y)} \{number(c2x)},\{number(c2y)} \{number(x)},\{number(y)}",
        )
      Close => parts.push("Z")
    }
  }
  parts.join(" ")
}

///|
fn color_text(color : Color) -> String {
  let channel = fn(value : Double) {
    let int = (clamp01(value) * 255.0).round().to_int()
    int.to_string()
  }
  if color.a >= 1.0 {
    "rgb(\{channel(color.r)},\{channel(color.g)},\{channel(color.b)})"
  } else {
    "rgba(\{channel(color.r)},\{channel(color.g)},\{channel(color.b)},\{number(color.a)})"
  }
}

///|
/// A surface that records every drawing call as one text line. Text is
/// measured as half the font size per character, so sketches can run headless
/// in native tests with deterministic output.
pub struct Recorder {
  log : Array[String]
}

///|
pub fn Recorder::new() -> Recorder {
  { log: [], }
}

///|
/// Returns the recorded calls and clears the log.
pub fn Recorder::take(self : Recorder) -> Array[String] {
  let output = self.log.copy()
  self.log.clear()
  output
}

///|
/// Peeks at the recorded calls without clearing.
pub fn Recorder::snapshot(self : Recorder) -> Array[String] {
  self.log.copy()
}

///|
pub impl Surface for Recorder with fn set_transform(self, matrix) {
  self.log.push(
    "transform \{number(matrix.a)} \{number(matrix.b)} \{number(matrix.c)} \{number(matrix.d)} \{number(matrix.tx)} \{number(matrix.ty)}",
  )
}

///|
pub impl Surface for Recorder with fn save(self) {
  self.log.push("save")
}

///|
pub impl Surface for Recorder with fn restore(self) {
  self.log.push("restore")
}

///|
pub impl Surface for Recorder with fn fill_path(self, path, color) {
  self.log.push("fill \{color_text(color)} \{path_text(path)}")
}

///|
pub impl Surface for Recorder with fn stroke_path(
  self,
  path,
  color,
  width,
  _cap,
  _join,
) {
  self.log.push(
    "stroke \{color_text(color)} w=\{number(width)} \{path_text(path)}",
  )
}

///|
pub impl Surface for Recorder with fn fill_rect(
  self,
  x,
  y,
  width,
  height,
  color,
) {
  self.log.push(
    "fill_rect \{color_text(color)} \{number(x)},\{number(y)},\{number(width)},\{number(height)}",
  )
}

///|
pub impl Surface for Recorder with fn fill_rounded_rect(
  self,
  x,
  y,
  width,
  height,
  radius,
  color,
) {
  self.log.push(
    "rrect \{color_text(color)} \{number(x)},\{number(y)},\{number(width)},\{number(height)} r=\{number(radius)}",
  )
}

///|
pub impl Surface for Recorder with fn stroke_rounded_rect(
  self,
  x,
  y,
  width,
  height,
  radius,
  color,
  stroke_width,
) {
  self.log.push(
    "srrect \{color_text(color)} w=\{number(stroke_width)} \{number(x)},\{number(y)},\{number(width)},\{number(height)} r=\{number(radius)}",
  )
}

///|
pub impl Surface for Recorder with fn clear_rect(self, x, y, width, height) {
  self.log.push(
    "clear_rect \{number(x)},\{number(y)},\{number(width)},\{number(height)}",
  )
}

///|
pub impl Surface for Recorder with fn draw_image(
  self,
  image,
  x,
  y,
  width,
  height,
  opacity,
  tint,
) {
  let tint = match tint {
    Some(color) => color_text(color)
    None => "none"
  }
  self.log.push(
    "image \{image.width()}x\{image.height()} at \{number(x)},\{number(y)} size=\{number(width)}x\{number(height)} opacity=\{number(opacity)} tint=\{tint}",
  )
}

///|
pub impl Surface for Recorder with fn clip_path(self, path) {
  self.log.push("clip \{path_text(path)}")
}

///|
pub impl Surface for Recorder with fn clip_end(self) {
  self.log.push("clip_end")
}

///|
pub impl Surface for Recorder with fn fill_text(
  self,
  text,
  x,
  y,
  color,
  stroke,
  stroke_width,
  font,
  align_h,
  align_v,
) {
  let stroke_suffix = match stroke {
    Some(stroke_color) =>
      " stroke=\{color_text(stroke_color)} w=\{number(stroke_width)}"
    None => ""
  }
  self.log.push(
    "text \{color_text(color)} \{text} at \{number(x)},\{number(y)} size=\{number(font.size)} align=\{align_h_text(align_h)}/\{align_v_text(align_v)}\{stroke_suffix}",
  )
}

///|
pub impl Surface for Recorder with fn measure_width(_, text, font) {
  text.length().to_double() * font.size * 0.5
}

///|
pub impl Surface for Recorder with fn text_metrics(_, font) {
  TextMetrics::new(
    width=0.0,
    height=font.size * 1.2,
    ascent=font.size * 0.8,
    descent=font.size * 0.2,
  )
}

///|
pub impl Surface for Recorder with fn set_blend_mode(self, mode) {
  self.log.push("blend \{blend_text(mode)}")
}

///|
pub impl Surface for Recorder with fn set_smoothing(self, enabled) {
  self.log.push("smooth \{enabled}")
}

///|
pub extend NullSurface with Surface::{
  set_transform,
  save,
  restore,
  fill_path,
  stroke_path,
  fill_rect,
  fill_rounded_rect,
  stroke_rounded_rect,
  clear_rect,
  draw_image,
  clip_path,
  clip_end,
  fill_text,
  measure_width,
  text_metrics,
  set_blend_mode,
  set_smoothing,
}

///|
pub extend Recorder with Surface::{
  set_transform,
  save,
  restore,
  fill_path,
  stroke_path,
  fill_rect,
  fill_rounded_rect,
  stroke_rounded_rect,
  clear_rect,
  draw_image,
  clip_path,
  clip_end,
  fill_text,
  measure_width,
  text_metrics,
  set_blend_mode,
  set_smoothing,
}
