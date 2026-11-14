///|
/// Multi-stop gradients: linear, radial and conic axes, optional Oklab mixing.
///
/// The legacy `LinearGradient`/`RadialGradient` brushes stay two-color and
/// untouched. This richer spec is one additive `Brush::StopsGradient` variant so
/// a renderer implements one shape: axis + sorted stops + an interpolation
/// choice. Renderers without native multi-stop support can call
/// `srgb_stops()`, which expands Oklab segments into sRGB samples.

///|
#derive(Eq, Debug, ToJson)
pub(all) struct GradientStop {
  color : Color
  /// Position along the gradient axis, clamped into 0.0..1.0.
  at : Double
}

///|
pub fn GradientStop::new(color~ : Color, at~ : Double) -> GradientStop {
  { color, at: clamp_gradient_at(at), }
}

///|
fn clamp_gradient_at(value : Double) -> Double {
  if value != value {
    0.0
  } else if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
/// Geometry of a stop gradient. `ConicAxis.angle_degrees` rotates the start of
/// the sweep clockwise from 12 o'clock, matching CSS `conic-gradient(from …)`.
#derive(Eq, Debug, ToJson)
pub(all) enum GradientAxis {
  LinearAxis(Point, Point)
  RadialAxis(Point, Double)
  ConicAxis(Point, Double)
}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct StopsGradientSpec {
  axis : GradientAxis
  stops : Array[GradientStop]
  /// Mix adjacent stops in Oklab instead of sRGB.
  oklab : Bool
}

///|
pub fn StopsGradientSpec::new(
  axis~ : GradientAxis,
  stops~ : Array[GradientStop],
  oklab~ : Bool = false,
) -> StopsGradientSpec {
  { axis, stops: normalize_gradient_stops(stops), oklab, }
}

///|
fn normalize_gradient_stops(stops : Array[GradientStop]) -> Array[GradientStop] {
  let normalized = stops.copy()
  for index in 0..<normalized.length() {
    normalized[index] = GradientStop::new(
      color=normalized[index].color,
      at=normalized[index].at,
    )
  }
  normalized.sort_by((a, b) => a.at.compare(b.at))
  normalized
}

///|
/// The stops a renderer without Oklab support can consume. Oklab segments are
/// subdivided into `resolution` sRGB samples; already-sRGB specs return a copy.
pub fn StopsGradientSpec::srgb_stops(
  self : StopsGradientSpec,
  resolution~ : Int32 = 16,
) -> Array[GradientStop] {
  if !self.oklab || self.stops.length() < 2 {
    return self.stops.copy()
  }
  let steps = resolution.max(2)
  let output : Array[GradientStop] = []
  for index in 0..<(self.stops.length() - 1) {
    let from = self.stops[index]
    let to = self.stops[index + 1]
    for step in 0..<steps {
      let t = step.to_double() / steps.to_double()
      output.push(
        GradientStop::new(
          color=Color::lerp_oklab(from.color, to.color, t),
          at=from.at + (to.at - from.at) * t,
        ),
      )
    }
  }
  output.push(self.stops[self.stops.length() - 1])
  output
}

///|
/// Sample the gradient at `t` in 0..1. Oklab specs mix in Oklab.
pub fn StopsGradientSpec::color_at(
  self : StopsGradientSpec,
  t : Double,
) -> Color {
  if self.stops.is_empty() {
    return Color::transparent()
  }
  let position = if t <= 0.0 { 0.0 } else if t >= 1.0 { 1.0 } else { t }
  for index in 0..<(self.stops.length() - 1) {
    let from = self.stops[index]
    let to = self.stops[index + 1]
    if position <= to.at {
      let span = to.at - from.at
      let segment_t = if span <= 0.0 {
        0.0
      } else {
        (position - from.at) / span
      }
      return if self.oklab {
        Color::lerp_oklab(from.color, to.color, segment_t)
      } else {
        from.color.lerp(to.color, segment_t)
      }
    }
  }
  self.stops[self.stops.length() - 1].color
}

///|
/// The first and last stop colors, the two-color fallback used by renderers
/// without multi-stop support. Empty stop lists report transparent for both.
pub fn StopsGradientSpec::edge_colors(
  self : StopsGradientSpec,
) -> (Color, Color) {
  let first = match self.stops.get(0) {
    Some(stop) => stop.color
    None => Color::transparent()
  }
  let last = match self.stops.get(self.stops.length() - 1) {
    Some(stop) => stop.color
    None => first
  }
  (first, last)
}

///|
/// Interpolate two colors in Oklab. Alpha interpolates linearly; RGB is mixed
/// through linear-light Oklab so saturated pairs keep their lightness instead
/// of passing through a dull gray midpoint.
pub fn Color::lerp_oklab(from : Color, to : Color, t : Double) -> Color {
  let amount = if t <= 0.0 { 0.0 } else if t >= 1.0 { 1.0 } else { t }
  let from_lab = oklab_from_color(from)
  let to_lab = oklab_from_color(to)
  let lab = Oklab::new(
    l=from_lab.l + (to_lab.l - from_lab.l) * amount,
    a=from_lab.a + (to_lab.a - from_lab.a) * amount,
    b=from_lab.b + (to_lab.b - from_lab.b) * amount,
  )
  let mixed = color_from_oklab(lab)
  Color::rgba(
    r=mixed.r,
    g=mixed.g,
    b=mixed.b,
    a=from.a + (to.a - from.a) * amount,
  )
}

///|
priv struct Oklab {
  l : Double
  a : Double
  b : Double
}

///|
fn Oklab::new(l~ : Double, a~ : Double, b~ : Double) -> Oklab {
  { l, a, b, }
}

///|
fn srgb_channel_to_linear(value : Double) -> Double {
  if value <= 0.04045 {
    value / 12.92
  } else {
    @math.pow((value + 0.055) / 1.055, 2.4)
  }
}

///|
fn linear_channel_to_srgb(value : Double) -> Double {
  if value <= 0.0031308 {
    value * 12.92
  } else {
    1.055 * @math.pow(value, 1.0 / 2.4) - 0.055
  }
}

///|
fn oklab_from_color(color : Color) -> Oklab {
  let r = srgb_channel_to_linear(color.r)
  let g = srgb_channel_to_linear(color.g)
  let b = srgb_channel_to_linear(color.b)
  let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
  let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
  let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
  let l_ = @math.cbrt(l)
  let m_ = @math.cbrt(m)
  let s_ = @math.cbrt(s)
  Oklab::new(
    l=0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
    a=1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
    b=0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
  )
}

///|
fn color_from_oklab(lab : Oklab) -> Color {
  let l_ = lab.l + 0.3963377774 * lab.a + 0.2158037573 * lab.b
  let m_ = lab.l - 0.1055613458 * lab.a - 0.0638541728 * lab.b
  let s_ = lab.l - 0.0894841775 * lab.a - 1.2914855480 * lab.b
  let l = l_ * l_ * l_
  let m = m_ * m_ * m_
  let s = s_ * s_ * s_
  let r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
  let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
  let b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
  Color::rgba(
    r=linear_channel_to_srgb(r).clamp(min=0.0, max=1.0),
    g=linear_channel_to_srgb(g).clamp(min=0.0, max=1.0),
    b=linear_channel_to_srgb(b).clamp(min=0.0, max=1.0),
    a=1.0,
  )
}

///|
/// Multi-stop linear gradient brush.
pub fn Brush::linear_stops(
  start~ : Point,
  end~ : Point,
  stops~ : Array[GradientStop],
  oklab~ : Bool = false,
) -> Brush {
  StopsGradient(
    StopsGradientSpec::new(axis=LinearAxis(start, end), stops~, oklab~),
  )
}

///|
/// Multi-stop radial gradient brush.
pub fn Brush::radial_stops(
  center~ : Point,
  radius~ : Double,
  stops~ : Array[GradientStop],
  oklab~ : Bool = false,
) -> Brush {
  StopsGradient(
    StopsGradientSpec::new(
      axis=RadialAxis(center, radius.max(0.0)),
      stops~,
      oklab~,
    ),
  )
}

///|
/// Multi-stop conic (sweep) gradient brush. `angle_degrees` rotates the start
/// of the sweep clockwise from 12 o'clock.
pub fn Brush::conic(
  center~ : Point,
  stops~ : Array[GradientStop],
  angle_degrees~ : Double = 0.0,
  oklab~ : Bool = false,
) -> Brush {
  StopsGradient(
    StopsGradientSpec::new(
      axis=ConicAxis(center, angle_degrees),
      stops~,
      oklab~,
    ),
  )
}
