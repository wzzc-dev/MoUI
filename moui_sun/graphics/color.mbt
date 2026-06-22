///|
/// RGBA color representation
pub(all) struct Color {
  r : Byte
  g : Byte
  b : Byte
  a : Byte
} derive(Eq, Debug)

///|
pub impl Show for Color with fn output(self, logger) {
  logger.write_string("Color::new(r=")
  logger.write_object(self.r)
  logger.write_string(", g=")
  logger.write_object(self.g)
  logger.write_string(", b=")
  logger.write_object(self.b)
  logger.write_string(", a=")
  logger.write_object(self.a)
  logger.write_string(")")
}

///|
/// Create a color from RGBA values
pub fn Color::new(r~ : Byte, g~ : Byte, b~ : Byte, a? : Byte = 255) -> Color {
  { r, g, b, a }
}

///|
/// Predefined colors
pub fn Color::white() -> Color {
  Color::new(r=255, g=255, b=255)
}

///|
pub fn Color::black() -> Color {
  Color::new(r=0, g=0, b=0)
}

///|
pub fn Color::red() -> Color {
  Color::new(r=255, g=0, b=0)
}

///|
pub fn Color::green() -> Color {
  Color::new(r=0, g=255, b=0)
}

///|
pub fn Color::blue() -> Color {
  Color::new(r=0, g=0, b=255)
}

///|
pub fn Color::transparent() -> Color {
  Color::new(r=0, g=0, b=0, a=0)
}

///|
/// Return this color with a replaced alpha channel
pub fn Color::with_alpha(self : Color, alpha : Byte) -> Color {
  { r: self.r, g: self.g, b: self.b, a: alpha }
}

///|
/// Return this color with its alpha multiplied by opacity
pub fn Color::scale_alpha(self : Color, opacity : Double) -> Color {
  let clamped = normalize_opacity(opacity)
  let alpha = (self.a.to_int().to_double() * clamped + 0.5).to_int()
  self.with_alpha(clamp_byte(alpha))
}

///|
fn normalize_opacity(opacity : Double) -> Double {
  guard opacity == opacity else { return 0.0 }
  if opacity < 0.0 {
    0.0
  } else if opacity > 1.0 {
    1.0
  } else {
    opacity
  }
}

///|
/// Composite this straight-alpha source color over a destination color
pub fn Color::blend_over(self : Color, dst : Color) -> Color {
  let src_a = self.a.to_int()
  let dst_a = dst.a.to_int()
  let inv_src_a = 255 - src_a
  let out_a = src_a + div_round(dst_a * inv_src_a, 255)

  guard out_a > 0 else { return Color::transparent() }

  let r_premul = self.r.to_int() * src_a +
    div_round(dst.r.to_int() * dst_a * inv_src_a, 255)
  let g_premul = self.g.to_int() * src_a +
    div_round(dst.g.to_int() * dst_a * inv_src_a, 255)
  let b_premul = self.b.to_int() * src_a +
    div_round(dst.b.to_int() * dst_a * inv_src_a, 255)

  Color::new(
    r=clamp_byte(div_round(r_premul, out_a)),
    g=clamp_byte(div_round(g_premul, out_a)),
    b=clamp_byte(div_round(b_premul, out_a)),
    a=clamp_byte(out_a),
  )
}

///|
/// Composite this straight-alpha source color over a destination color using
/// a configured blend mode.
pub fn Color::blend_with(
  self : Color,
  dst : Color,
  blend_mode : BlendMode,
) -> Color {
  match blend_mode {
    BlendMode::Clear => Color::transparent()
    BlendMode::Source => self
    BlendMode::Destination => dst
    BlendMode::SourceOver => self.blend_over(dst)
    BlendMode::DestinationOver => dst.blend_over(self)
    BlendMode::SourceIn => self.blend_alpha_mask(dst.a.to_int())
    BlendMode::DestinationIn => dst.blend_alpha_mask(self.a.to_int())
    BlendMode::SourceOut => self.blend_alpha_mask(255 - dst.a.to_int())
    BlendMode::DestinationOut => dst.blend_alpha_mask(255 - self.a.to_int())
    BlendMode::SourceAtop =>
      blend_porter_duff(
        self,
        dst,
        src_factor=dst.a.to_int(),
        dst_factor=255 - self.a.to_int(),
        out_alpha=dst.a.to_int(),
      )
    BlendMode::DestinationAtop =>
      blend_porter_duff(
        self,
        dst,
        src_factor=255 - dst.a.to_int(),
        dst_factor=self.a.to_int(),
        out_alpha=self.a.to_int(),
      )
    BlendMode::Xor =>
      blend_porter_duff(
        self,
        dst,
        src_factor=255 - dst.a.to_int(),
        dst_factor=255 - self.a.to_int(),
        out_alpha=div_round(self.a.to_int() * (255 - dst.a.to_int()), 255) +
          div_round(dst.a.to_int() * (255 - self.a.to_int()), 255),
      )
    BlendMode::Multiply
    | BlendMode::Screen
    | BlendMode::Add
    | BlendMode::Darken
    | BlendMode::Lighten
    | BlendMode::Difference
    | BlendMode::Exclusion
    | BlendMode::Overlay
    | BlendMode::HardLight
    | BlendMode::SoftLight
    | BlendMode::ColorDodge
    | BlendMode::ColorBurn
    | BlendMode::Hue
    | BlendMode::Saturation
    | BlendMode::Color
    | BlendMode::Luminosity
    | BlendMode::LinearBurn
    | BlendMode::Subtract => blend_non_source_over(self, dst, blend_mode)
  }
}

///|
fn should_blend_source_color(color : Color, blend_mode : BlendMode) -> Bool {
  match blend_mode {
    BlendMode::Destination => false
    _ =>
      color.a.to_int() > 0 || blend_mode_blends_transparent_source(blend_mode)
  }
}

///|
fn blend_mode_blends_transparent_source(blend_mode : BlendMode) -> Bool {
  match blend_mode {
    BlendMode::Clear
    | BlendMode::Source
    | BlendMode::SourceIn
    | BlendMode::SourceOut
    | BlendMode::DestinationIn
    | BlendMode::DestinationAtop => true
    _ => false
  }
}

///|
fn blend_porter_duff(
  src : Color,
  dst : Color,
  src_factor~ : Int,
  dst_factor~ : Int,
  out_alpha~ : Int,
) -> Color {
  guard out_alpha > 0 else { return Color::transparent() }
  let src_a = src.a.to_int()
  let dst_a = dst.a.to_int()
  Color::new(
    r=blend_porter_duff_channel(
      src.r,
      src_a,
      src_factor,
      dst.r,
      dst_a,
      dst_factor,
      out_alpha,
    ),
    g=blend_porter_duff_channel(
      src.g,
      src_a,
      src_factor,
      dst.g,
      dst_a,
      dst_factor,
      out_alpha,
    ),
    b=blend_porter_duff_channel(
      src.b,
      src_a,
      src_factor,
      dst.b,
      dst_a,
      dst_factor,
      out_alpha,
    ),
    a=clamp_byte(out_alpha),
  )
}

///|
fn blend_porter_duff_channel(
  src_channel : Byte,
  src_a : Int,
  src_factor : Int,
  dst_channel : Byte,
  dst_a : Int,
  dst_factor : Int,
  out_alpha : Int,
) -> Byte {
  let premul = div_round(
      src_channel.to_int() * src_a * src_factor.max(0).min(255),
      255,
    ) +
    div_round(dst_channel.to_int() * dst_a * dst_factor.max(0).min(255), 255)
  clamp_byte(div_round(premul, out_alpha))
}

///|
fn blend_non_source_over(
  src : Color,
  dst : Color,
  blend_mode : BlendMode,
) -> Color {
  let src_a = src.a.to_int()
  let dst_a = dst.a.to_int()
  let inv_src_a = 255 - src_a
  let inv_dst_a = 255 - dst_a
  let out_a = src_a + div_round(dst_a * inv_src_a, 255)
  guard out_a > 0 else { return Color::transparent() }
  let (blended_r, blended_g, blended_b) = blend_unpremul_rgb(
    src, dst, blend_mode,
  )
  Color::new(
    r=blend_non_source_over_channel(
      src.r.to_int(),
      src_a,
      dst.r.to_int(),
      dst_a,
      inv_src_a,
      inv_dst_a,
      out_a,
      blended_r,
    ),
    g=blend_non_source_over_channel(
      src.g.to_int(),
      src_a,
      dst.g.to_int(),
      dst_a,
      inv_src_a,
      inv_dst_a,
      out_a,
      blended_g,
    ),
    b=blend_non_source_over_channel(
      src.b.to_int(),
      src_a,
      dst.b.to_int(),
      dst_a,
      inv_src_a,
      inv_dst_a,
      out_a,
      blended_b,
    ),
    a=clamp_byte(out_a),
  )
}

///|
fn blend_non_source_over_channel(
  src_c : Int,
  src_a : Int,
  dst_c : Int,
  dst_a : Int,
  inv_src_a : Int,
  inv_dst_a : Int,
  out_a : Int,
  blended : Int,
) -> Byte {
  let premul = blended * src_a * dst_a +
    src_c * src_a * inv_dst_a +
    dst_c * dst_a * inv_src_a
  clamp_byte(div_round(premul, out_a * 255))
}

///|
fn blend_unpremul_rgb(
  src : Color,
  dst : Color,
  blend_mode : BlendMode,
) -> (Int, Int, Int) {
  match blend_mode {
    BlendMode::Hue =>
      rounded_blend_rgb(
        blend_nonseparable_hue(color_to_blend_rgb(src), color_to_blend_rgb(dst)),
      )
    BlendMode::Saturation =>
      rounded_blend_rgb(
        blend_nonseparable_saturation(
          color_to_blend_rgb(src),
          color_to_blend_rgb(dst),
        ),
      )
    BlendMode::Color =>
      rounded_blend_rgb(
        blend_nonseparable_color(
          color_to_blend_rgb(src),
          color_to_blend_rgb(dst),
        ),
      )
    BlendMode::Luminosity =>
      rounded_blend_rgb(
        blend_nonseparable_luminosity(
          color_to_blend_rgb(src),
          color_to_blend_rgb(dst),
        ),
      )
    _ =>
      (
        blend_unpremul_channel(src.r.to_int(), dst.r.to_int(), blend_mode),
        blend_unpremul_channel(src.g.to_int(), dst.g.to_int(), blend_mode),
        blend_unpremul_channel(src.b.to_int(), dst.b.to_int(), blend_mode),
      )
  }
}

///|
fn blend_unpremul_channel(src : Int, dst : Int, blend_mode : BlendMode) -> Int {
  match blend_mode {
    BlendMode::Clear => 0
    BlendMode::Source => src
    BlendMode::Destination => dst
    BlendMode::SourceOver => src
    BlendMode::DestinationOver => dst
    BlendMode::SourceIn | BlendMode::SourceOut | BlendMode::SourceAtop => src
    BlendMode::DestinationIn
    | BlendMode::DestinationOut
    | BlendMode::DestinationAtop => dst
    BlendMode::Xor => src
    BlendMode::Multiply => div_round(src * dst, 255)
    BlendMode::Screen => 255 - div_round((255 - src) * (255 - dst), 255)
    BlendMode::Add => (src + dst).min(255)
    BlendMode::Darken => src.min(dst)
    BlendMode::Lighten => src.max(dst)
    BlendMode::Difference => (src - dst).abs()
    BlendMode::Exclusion => src + dst - div_round(2 * src * dst, 255)
    BlendMode::Overlay =>
      if dst < 128 {
        div_round(2 * src * dst, 255)
      } else {
        255 - div_round(2 * (255 - src) * (255 - dst), 255)
      }
    BlendMode::HardLight =>
      if src < 128 {
        div_round(2 * src * dst, 255)
      } else {
        255 - div_round(2 * (255 - src) * (255 - dst), 255)
      }
    BlendMode::SoftLight => blend_soft_light_channel(src, dst)
    BlendMode::ColorDodge => blend_color_dodge_channel(src, dst)
    BlendMode::ColorBurn => blend_color_burn_channel(src, dst)
    // Non-separable modes are handled by blend_unpremul_rgb before channel fallback.
    BlendMode::Hue
    | BlendMode::Saturation
    | BlendMode::Color
    | BlendMode::Luminosity => src
    BlendMode::LinearBurn => (src + dst - 255).max(0)
    BlendMode::Subtract => (dst - src).max(0)
  }
}

///|
fn color_to_blend_rgb(color : Color) -> (Double, Double, Double) {
  (
    color.r.to_int().to_double(),
    color.g.to_int().to_double(),
    color.b.to_int().to_double(),
  )
}

///|
fn blend_nonseparable_hue(
  src : (Double, Double, Double),
  dst : (Double, Double, Double),
) -> (Double, Double, Double) {
  set_lum(set_sat(src, sat(dst)), lum(dst))
}

///|
fn blend_nonseparable_saturation(
  src : (Double, Double, Double),
  dst : (Double, Double, Double),
) -> (Double, Double, Double) {
  set_lum(set_sat(dst, sat(src)), lum(dst))
}

///|
fn blend_nonseparable_color(
  src : (Double, Double, Double),
  dst : (Double, Double, Double),
) -> (Double, Double, Double) {
  set_lum(src, lum(dst))
}

///|
fn blend_nonseparable_luminosity(
  src : (Double, Double, Double),
  dst : (Double, Double, Double),
) -> (Double, Double, Double) {
  set_lum(dst, lum(src))
}

///|
fn lum(color : (Double, Double, Double)) -> Double {
  let (r, g, b) = color
  0.3 * r + 0.59 * g + 0.11 * b
}

///|
fn sat(color : (Double, Double, Double)) -> Double {
  max_rgb(color) - min_rgb(color)
}

///|
fn set_lum(
  color : (Double, Double, Double),
  target_lum : Double,
) -> (Double, Double, Double) {
  let (r, g, b) = color
  let delta = target_lum - lum(color)
  clip_color((r + delta, g + delta, b + delta))
}

///|
fn set_sat(
  color : (Double, Double, Double),
  target_sat : Double,
) -> (Double, Double, Double) {
  let (r, g, b) = color
  let min_value = min_rgb(color)
  let max_value = max_rgb(color)
  guard max_value > min_value else { return (0.0, 0.0, 0.0) }
  let scale = target_sat / (max_value - min_value)
  (
    set_sat_component(r, min_value, max_value, target_sat, scale),
    set_sat_component(g, min_value, max_value, target_sat, scale),
    set_sat_component(b, min_value, max_value, target_sat, scale),
  )
}

///|
fn set_sat_component(
  value : Double,
  min_value : Double,
  max_value : Double,
  target_sat : Double,
  scale : Double,
) -> Double {
  if value == min_value {
    0.0
  } else if value == max_value {
    target_sat
  } else {
    (value - min_value) * scale
  }
}

///|
fn clip_color(color : (Double, Double, Double)) -> (Double, Double, Double) {
  let (r, g, b) = color
  let target_lum = 0.3 * r + 0.59 * g + 0.11 * b
  let min_value = r.min(g).min(b)
  let clipped = if min_value < 0.0 {
    let scale = target_lum / (target_lum - min_value)
    (
      target_lum + (r - target_lum) * scale,
      target_lum + (g - target_lum) * scale,
      target_lum + (b - target_lum) * scale,
    )
  } else {
    color
  }
  let (clipped_r, clipped_g, clipped_b) = clipped
  let clipped_lum = 0.3 * clipped_r + 0.59 * clipped_g + 0.11 * clipped_b
  let clipped_max = clipped_r.max(clipped_g).max(clipped_b)
  if clipped_max > 255.0 {
    let scale = (255.0 - clipped_lum) / (clipped_max - clipped_lum)
    (
      clipped_lum + (clipped_r - clipped_lum) * scale,
      clipped_lum + (clipped_g - clipped_lum) * scale,
      clipped_lum + (clipped_b - clipped_lum) * scale,
    )
  } else {
    (clipped_r, clipped_g, clipped_b)
  }
}

///|
fn min_rgb(color : (Double, Double, Double)) -> Double {
  let (r, g, b) = color
  r.min(g).min(b)
}

///|
fn max_rgb(color : (Double, Double, Double)) -> Double {
  let (r, g, b) = color
  r.max(g).max(b)
}

///|
fn rounded_blend_rgb(color : (Double, Double, Double)) -> (Int, Int, Int) {
  let (r, g, b) = color
  (rounded_blend_byte(r), rounded_blend_byte(g), rounded_blend_byte(b))
}

///|
fn rounded_blend_byte(value : Double) -> Int {
  clamp_byte((value + 0.5).to_int()).to_int()
}

///|
fn Color::blend_alpha_mask(self : Color, alpha_factor : Int) -> Color {
  let out_a = div_round(self.a.to_int() * alpha_factor.max(0).min(255), 255)
  guard out_a > 0 else { return Color::transparent() }
  self.with_alpha(clamp_byte(out_a))
}

///|
fn blend_color_dodge_channel(src : Int, dst : Int) -> Int {
  if dst <= 0 {
    0
  } else if src >= 255 {
    255
  } else {
    div_round(dst * 255, 255 - src).min(255)
  }
}

///|
fn blend_color_burn_channel(src : Int, dst : Int) -> Int {
  if dst >= 255 {
    255
  } else if src <= 0 {
    0
  } else {
    255 - div_round((255 - dst) * 255, src).min(255)
  }
}

///|
fn blend_soft_light_channel(src : Int, dst : Int) -> Int {
  let cs = src.to_double() / 255.0
  let cb = dst.to_double() / 255.0
  let blended = if cs <= 0.5 {
    cb - (1.0 - 2.0 * cs) * cb * (1.0 - cb)
  } else {
    let d = if cb <= 0.25 {
      ((16.0 * cb - 12.0) * cb + 4.0) * cb
    } else {
      cb.sqrt()
    }
    cb + (2.0 * cs - 1.0) * (d - cb)
  }
  clamp_byte((blended * 255.0 + 0.5).to_int()).to_int()
}

///|
fn div_round(numerator : Int, denominator : Int) -> Int {
  guard denominator > 0 else { return 0 }
  (numerator + denominator / 2) / denominator
}

///|
fn clamp_byte(value : Int) -> Byte {
  value.max(0).min(255).to_byte()
}
