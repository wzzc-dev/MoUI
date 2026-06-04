///|
/// Value-layer paint state modeled after `skia_safe::Paint`.
///
/// Native Skia paints will use a separate handle type once the C++ FFI layer is
/// wired to real Skia binaries.
pub(all) struct Paint {
  color : Color
  anti_alias : Bool
  dither : Bool
  style : PaintStyle
  stroke_width : Scalar
  stroke_miter : Scalar
  stroke_cap : StrokeCap
  stroke_join : StrokeJoin
  blend_mode : BlendMode
} derive(Debug, Eq)

///|
pub fn Paint::new(
  color? : Color = Color::black(),
  anti_alias? : Bool = false,
  dither? : Bool = false,
  style? : PaintStyle = Fill,
  stroke_width? : Scalar = 0,
  stroke_miter? : Scalar = 4,
  stroke_cap? : StrokeCap = Butt,
  stroke_join? : StrokeJoin = Miter,
  blend_mode? : BlendMode = SrcOver,
) -> Paint {
  {
    color,
    anti_alias,
    dither,
    style,
    stroke_width,
    stroke_miter,
    stroke_cap,
    stroke_join,
    blend_mode,
  }
}

///|
pub impl Default for Paint with fn default() {
  Paint::new()
}

///|
pub fn Paint::reset(self : Paint) -> Paint {
  ignore(self)
  Paint::new()
}

///|
pub fn Paint::set_color(self : Paint, color : Color) -> Paint {
  { ..self, color, }
}

///|
pub fn Paint::set_argb(
  self : Paint,
  a : Byte,
  r : Byte,
  g : Byte,
  b : Byte,
) -> Paint {
  self.set_color(Color::from_argb(a, r, g, b))
}

///|
pub fn Paint::alpha(self : Paint) -> Byte {
  self.color.a()
}

///|
pub fn Paint::set_alpha(self : Paint, alpha : Byte) -> Paint {
  self.set_color(self.color.with_alpha(alpha))
}

///|
pub fn Paint::set_anti_alias(self : Paint, anti_alias : Bool) -> Paint {
  { ..self, anti_alias, }
}

///|
pub fn Paint::set_dither(self : Paint, dither : Bool) -> Paint {
  { ..self, dither, }
}

///|
pub fn Paint::set_style(self : Paint, style : PaintStyle) -> Paint {
  { ..self, style, }
}

///|
pub fn Paint::set_stroke(self : Paint, stroke : Bool) -> Paint {
  if stroke {
    self.set_style(Stroke)
  } else {
    self.set_style(Fill)
  }
}

///|
pub fn Paint::set_stroke_width(self : Paint, stroke_width : Scalar) -> Paint {
  { ..self, stroke_width, }
}

///|
pub fn Paint::set_stroke_miter(self : Paint, stroke_miter : Scalar) -> Paint {
  { ..self, stroke_miter, }
}

///|
pub fn Paint::set_stroke_cap(self : Paint, stroke_cap : StrokeCap) -> Paint {
  { ..self, stroke_cap, }
}

///|
pub fn Paint::set_stroke_join(self : Paint, stroke_join : StrokeJoin) -> Paint {
  { ..self, stroke_join, }
}

///|
pub fn Paint::set_blend_mode(self : Paint, blend_mode : BlendMode) -> Paint {
  { ..self, blend_mode, }
}

///|
pub fn Paint::color_argb(self : Paint) -> UInt {
  self.color.argb()
}

///|
pub fn Paint::style_ordinal(self : Paint) -> Int {
  self.style.to_skia_ordinal()
}

///|
pub fn Paint::stroke_cap_ordinal(self : Paint) -> Int {
  self.stroke_cap.to_skia_ordinal()
}

///|
pub fn Paint::stroke_join_ordinal(self : Paint) -> Int {
  self.stroke_join.to_skia_ordinal()
}

///|
pub fn Paint::blend_mode_ordinal(self : Paint) -> Int {
  self.blend_mode.to_skia_ordinal()
}
