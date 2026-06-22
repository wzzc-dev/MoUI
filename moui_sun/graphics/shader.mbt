///|
/// Device-space shader used as a Paint color source.
struct PaintShader {
  kind : PaintShaderKind
  local_from_device : Transform?
  transform_valid : Bool
} derive(Eq, Debug)

///|
/// One color stop in a gradient shader.
struct PaintGradientStop {
  offset : Double
  color : Color
} derive(Eq, Debug)

///|
/// Spread mode applied to gradient coordinates outside the unit interval.
pub(all) enum PaintShaderSpread {
  Clamp
  Repeat
  Mirror
  Decal
} derive(Eq, Debug)

///|
/// Public shader family used for inspection and paint pipeline planning.
pub(all) enum PaintShaderType {
  LinearGradient
  RadialGradient
  SweepGradient
} derive(Eq, Debug)

///|
priv enum PaintShaderKind {
  LinearGradient(LinearGradientShader)
  LinearGradientStops(LinearGradientStopsShader)
  RadialGradient(RadialGradientShader)
  RadialGradientStops(RadialGradientStopsShader)
  SweepGradient(SweepGradientShader)
  SweepGradientStops(SweepGradientStopsShader)
} derive(Eq, Debug)

///|
priv struct LinearGradientShader {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
  start_color : Color
  end_color : Color
  spread : PaintShaderSpread
} derive(Eq, Debug)

///|
priv struct LinearGradientStopsShader {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
  stops : Array[PaintGradientStop]
  spread : PaintShaderSpread
} derive(Eq, Debug)

///|
priv struct RadialGradientShader {
  cx : Double
  cy : Double
  radius : Double
  start_color : Color
  end_color : Color
  spread : PaintShaderSpread
} derive(Eq, Debug)

///|
priv struct RadialGradientStopsShader {
  cx : Double
  cy : Double
  radius : Double
  stops : Array[PaintGradientStop]
  spread : PaintShaderSpread
} derive(Eq, Debug)

///|
priv struct SweepGradientShader {
  cx : Double
  cy : Double
  start_angle : Double
  sweep_angle : Double
  start_color : Color
  end_color : Color
  spread : PaintShaderSpread
} derive(Eq, Debug)

///|
priv struct SweepGradientStopsShader {
  cx : Double
  cy : Double
  start_angle : Double
  sweep_angle : Double
  stops : Array[PaintGradientStop]
  spread : PaintShaderSpread
} derive(Eq, Debug)

///|
/// Create a gradient color stop. Offsets are clamped into 0.0..1.0.
pub fn PaintGradientStop::new(
  offset~ : Double,
  color~ : Color,
) -> PaintGradientStop {
  { offset: normalize_gradient_stop_offset(offset), color }
}

///|
/// Return this stop's normalized offset.
pub fn PaintGradientStop::get_offset(self : PaintGradientStop) -> Double {
  self.offset
}

///|
/// Return this stop's color.
pub fn PaintGradientStop::get_color(self : PaintGradientStop) -> Color {
  self.color
}

///|
/// Create a device-space linear gradient shader.
pub fn PaintShader::linear_gradient(
  x0~ : Double,
  y0~ : Double,
  x1~ : Double,
  y1~ : Double,
  start_color~ : Color,
  end_color~ : Color,
  spread? : PaintShaderSpread = PaintShaderSpread::Clamp,
) -> PaintShader {
  make_paint_shader(
    LinearGradient({ x0, y0, x1, y1, start_color, end_color, spread }),
  )
}

///|
/// Create a device-space linear gradient shader with multiple color stops.
pub fn PaintShader::linear_gradient_stops(
  x0~ : Double,
  y0~ : Double,
  x1~ : Double,
  y1~ : Double,
  stops~ : Array[PaintGradientStop],
  spread? : PaintShaderSpread = PaintShaderSpread::Clamp,
) -> PaintShader {
  make_paint_shader(
    LinearGradientStops({
      x0,
      y0,
      x1,
      y1,
      stops: copy_gradient_stops(stops),
      spread,
    }),
  )
}

///|
/// Create a device-space radial gradient shader.
pub fn PaintShader::radial_gradient(
  cx~ : Double,
  cy~ : Double,
  radius~ : Double,
  start_color~ : Color,
  end_color~ : Color,
  spread? : PaintShaderSpread = PaintShaderSpread::Clamp,
) -> PaintShader {
  make_paint_shader(
    RadialGradient({
      cx,
      cy,
      radius: normalize_radial_gradient_radius(radius),
      start_color,
      end_color,
      spread,
    }),
  )
}

///|
/// Create a device-space radial gradient shader with multiple color stops.
pub fn PaintShader::radial_gradient_stops(
  cx~ : Double,
  cy~ : Double,
  radius~ : Double,
  stops~ : Array[PaintGradientStop],
  spread? : PaintShaderSpread = PaintShaderSpread::Clamp,
) -> PaintShader {
  make_paint_shader(
    RadialGradientStops({
      cx,
      cy,
      radius: normalize_radial_gradient_radius(radius),
      stops: copy_gradient_stops(stops),
      spread,
    }),
  )
}

///|
/// Create a device-space sweep gradient shader around a center point.
pub fn PaintShader::sweep_gradient(
  cx~ : Double,
  cy~ : Double,
  start_angle~ : Double,
  sweep_angle~ : Double,
  start_color~ : Color,
  end_color~ : Color,
  spread? : PaintShaderSpread = PaintShaderSpread::Clamp,
) -> PaintShader {
  make_paint_shader(
    SweepGradient({
      cx,
      cy,
      start_angle: normalize_sweep_gradient_start_angle(start_angle),
      sweep_angle: normalize_sweep_gradient_sweep_angle(sweep_angle),
      start_color,
      end_color,
      spread,
    }),
  )
}

///|
/// Create a device-space sweep gradient shader with multiple color stops.
pub fn PaintShader::sweep_gradient_stops(
  cx~ : Double,
  cy~ : Double,
  start_angle~ : Double,
  sweep_angle~ : Double,
  stops~ : Array[PaintGradientStop],
  spread? : PaintShaderSpread = PaintShaderSpread::Clamp,
) -> PaintShader {
  make_paint_shader(
    SweepGradientStops({
      cx,
      cy,
      start_angle: normalize_sweep_gradient_start_angle(start_angle),
      sweep_angle: normalize_sweep_gradient_sweep_angle(sweep_angle),
      stops: copy_gradient_stops(stops),
      spread,
    }),
  )
}

///|
/// Return the shader family.
pub fn PaintShader::get_type(self : PaintShader) -> PaintShaderType {
  match self.kind {
    LinearGradient(_) | LinearGradientStops(_) =>
      PaintShaderType::LinearGradient
    RadialGradient(_) | RadialGradientStops(_) =>
      PaintShaderType::RadialGradient
    SweepGradient(_) | SweepGradientStops(_) => PaintShaderType::SweepGradient
  }
}

///|
/// Return the gradient spread mode.
pub fn PaintShader::get_spread(self : PaintShader) -> PaintShaderSpread {
  match self.kind {
    LinearGradient(shader) => shader.spread
    LinearGradientStops(shader) => shader.spread
    RadialGradient(shader) => shader.spread
    RadialGradientStops(shader) => shader.spread
    SweepGradient(shader) => shader.spread
    SweepGradientStops(shader) => shader.spread
  }
}

///|
/// Return the number of color stops used by this gradient. Two-color gradient
/// constructors report their implicit start/end stop pair.
pub fn PaintShader::get_gradient_stop_count(self : PaintShader) -> Int {
  match self.kind {
    LinearGradient(_) | RadialGradient(_) | SweepGradient(_) => 2
    LinearGradientStops(shader) => shader.stops.length()
    RadialGradientStops(shader) => shader.stops.length()
    SweepGradientStops(shader) => shader.stops.length()
  }
}

///|
/// Return a copied gradient stop list. Two-color gradient constructors expose
/// their implicit start/end pair as stops at 0.0 and 1.0.
pub fn PaintShader::get_gradient_stops(
  self : PaintShader,
) -> Array[PaintGradientStop] {
  match self.kind {
    LinearGradient(shader) =>
      two_gradient_stops(shader.start_color, shader.end_color)
    LinearGradientStops(shader) => copy_gradient_stops(shader.stops)
    RadialGradient(shader) =>
      two_gradient_stops(shader.start_color, shader.end_color)
    RadialGradientStops(shader) => copy_gradient_stops(shader.stops)
    SweepGradient(shader) =>
      two_gradient_stops(shader.start_color, shader.end_color)
    SweepGradientStops(shader) => copy_gradient_stops(shader.stops)
  }
}

///|
/// Return a copied gradient stop at an index.
pub fn PaintShader::get_gradient_stop(
  self : PaintShader,
  index : Int,
) -> PaintGradientStop? {
  let stops = self.get_gradient_stops()
  guard index >= 0 && index < stops.length() else { return None }
  Some(stops[index])
}

///|
/// Return local linear-gradient endpoints, if this is a linear gradient.
pub fn PaintShader::get_linear_gradient_points(
  self : PaintShader,
) -> (Point, Point)? {
  match self.kind {
    LinearGradient(shader) =>
      Some(
        (
          Point::new(x=shader.x0, y=shader.y0),
          Point::new(x=shader.x1, y=shader.y1),
        ),
      )
    LinearGradientStops(shader) =>
      Some(
        (
          Point::new(x=shader.x0, y=shader.y0),
          Point::new(x=shader.x1, y=shader.y1),
        ),
      )
    _ => None
  }
}

///|
/// Return local radial-gradient center and radius, if this is a radial gradient.
pub fn PaintShader::get_radial_gradient_circle(
  self : PaintShader,
) -> (Point, Double)? {
  match self.kind {
    RadialGradient(shader) =>
      Some((Point::new(x=shader.cx, y=shader.cy), shader.radius))
    RadialGradientStops(shader) =>
      Some((Point::new(x=shader.cx, y=shader.cy), shader.radius))
    _ => None
  }
}

///|
/// Return local sweep-gradient center and angles, if this is a sweep gradient.
pub fn PaintShader::get_sweep_gradient_geometry(
  self : PaintShader,
) -> (Point, Double, Double)? {
  match self.kind {
    SweepGradient(shader) =>
      Some(
        (
          Point::new(x=shader.cx, y=shader.cy),
          shader.start_angle,
          shader.sweep_angle,
        ),
      )
    SweepGradientStops(shader) =>
      Some(
        (
          Point::new(x=shader.cx, y=shader.cy),
          shader.start_angle,
          shader.sweep_angle,
        ),
      )
    _ => None
  }
}

///|
/// Return whether this shader has a local-to-device transform attached.
pub fn PaintShader::has_local_transform(self : PaintShader) -> Bool {
  self.local_from_device is Some(_)
}

///|
/// Return the local-from-device transform used before sampling, if any.
pub fn PaintShader::get_local_from_device_transform(
  self : PaintShader,
) -> Transform? {
  self.local_from_device
}

///|
/// Return whether this shader can produce non-transparent samples. Singular
/// transforms mark a shader as unsampleable.
pub fn PaintShader::is_sampleable(self : PaintShader) -> Bool {
  self.transform_valid
}

///|
/// Return a shader sampled in local coordinates mapped to device space by the
/// given transform. Singular transforms make the shader sample transparent.
pub fn PaintShader::transformed(
  self : PaintShader,
  transform : Transform,
) -> PaintShader {
  guard self.transform_valid else {
    return { kind: self.kind, local_from_device: None, transform_valid: false }
  }
  match transform.inverse() {
    Some(inverse) => {
      let local_from_device = non_identity_shader_transform(
        match self.local_from_device {
          Some(existing) => existing.multiply(inverse)
          None => inverse
        },
      )
      { kind: self.kind, local_from_device, transform_valid: true }
    }
    None => { kind: self.kind, local_from_device: None, transform_valid: false }
  }
}

///|
fn non_identity_shader_transform(transform : Transform) -> Transform? {
  if transform == Transform::identity() {
    None
  } else {
    Some(transform)
  }
}

///|
/// Sample this shader at a device-space point.
pub fn PaintShader::sample(self : PaintShader, x : Double, y : Double) -> Color {
  guard self.transform_valid else { return Color::transparent() }
  let (local_x, local_y) = match self.local_from_device {
    Some(transform) => transform.apply(x, y)
    None => (x, y)
  }
  self.sample_local(local_x, local_y)
}

///|
fn make_paint_shader(kind : PaintShaderKind) -> PaintShader {
  { kind, local_from_device: None, transform_valid: true }
}

///|
fn PaintShader::sample_local(
  self : PaintShader,
  x : Double,
  y : Double,
) -> Color {
  match self.kind {
    LinearGradient(shader) => shader.sample(x, y)
    LinearGradientStops(shader) => shader.sample(x, y)
    RadialGradient(shader) => shader.sample(x, y)
    RadialGradientStops(shader) => shader.sample(x, y)
    SweepGradient(shader) => shader.sample(x, y)
    SweepGradientStops(shader) => shader.sample(x, y)
  }
}

///|
fn LinearGradientShader::sample(
  self : LinearGradientShader,
  x : Double,
  y : Double,
) -> Color {
  lerp_gradient_color(
    self.start_color,
    self.end_color,
    linear_gradient_t(self.x0, self.y0, self.x1, self.y1, x, y, self.spread),
  )
}

///|
fn LinearGradientStopsShader::sample(
  self : LinearGradientStopsShader,
  x : Double,
  y : Double,
) -> Color {
  sample_gradient_stops(
    self.stops,
    linear_gradient_t(self.x0, self.y0, self.x1, self.y1, x, y, self.spread),
  )
}

///|
fn RadialGradientShader::sample(
  self : RadialGradientShader,
  x : Double,
  y : Double,
) -> Color {
  let t = radial_gradient_t(self.cx, self.cy, self.radius, x, y, self.spread)
  lerp_gradient_color(self.start_color, self.end_color, t)
}

///|
fn RadialGradientStopsShader::sample(
  self : RadialGradientStopsShader,
  x : Double,
  y : Double,
) -> Color {
  sample_gradient_stops(
    self.stops,
    radial_gradient_t(self.cx, self.cy, self.radius, x, y, self.spread),
  )
}

///|
fn SweepGradientShader::sample(
  self : SweepGradientShader,
  x : Double,
  y : Double,
) -> Color {
  let t = sweep_gradient_t(
    self.cx,
    self.cy,
    self.start_angle,
    self.sweep_angle,
    x,
    y,
    self.spread,
  )
  lerp_gradient_color(self.start_color, self.end_color, t)
}

///|
fn SweepGradientStopsShader::sample(
  self : SweepGradientStopsShader,
  x : Double,
  y : Double,
) -> Color {
  sample_gradient_stops(
    self.stops,
    sweep_gradient_t(
      self.cx,
      self.cy,
      self.start_angle,
      self.sweep_angle,
      x,
      y,
      self.spread,
    ),
  )
}

///|
fn clamp_unit(value : Double) -> Double {
  guard value == value else { return 0.0 }
  guard value - value == value - value else {
    if value < 0.0 {
      0.0
    } else {
      1.0
    }
  }
  value.max(0.0).min(1.0)
}

///|
fn sweep_relative_angle(
  angle : Double,
  start_angle : Double,
  sweep_angle : Double,
) -> Double {
  if sweep_angle >= 0.0 {
    normalize_positive_angle(angle - start_angle)
  } else {
    -normalize_positive_angle(start_angle - angle)
  }
}

///|
fn normalize_positive_angle(value : Double) -> Double {
  let two_pi = @math.PI * 2.0
  guard two_pi > 0.0 else { return 0.0 }
  let turns = value / two_pi
  (turns - @math.floor(turns)) * two_pi
}

///|
fn normalize_radial_gradient_radius(radius : Double) -> Double {
  if radius > 0.000000001 {
    radius
  } else {
    0.0
  }
}

///|
fn normalize_sweep_gradient_start_angle(angle : Double) -> Double {
  guard angle == angle else { return 0.0 }
  angle
}

///|
fn normalize_sweep_gradient_sweep_angle(angle : Double) -> Double {
  guard angle == angle else { return 0.0 }
  if angle.abs() > 0.000000001 {
    angle
  } else {
    0.0
  }
}

///|
fn apply_shader_spread(value : Double, spread : PaintShaderSpread) -> Double {
  guard value == value else { return 0.0 }
  guard value - value == value - value else {
    match spread {
      PaintShaderSpread::Clamp => if value < 0.0 { 0.0 } else { 1.0 }
      PaintShaderSpread::Repeat | PaintShaderSpread::Mirror => 0.0
      PaintShaderSpread::Decal => -1.0
    }
  }
  match spread {
    PaintShaderSpread::Clamp => clamp_unit(value)
    PaintShaderSpread::Repeat => repeat_unit(value)
    PaintShaderSpread::Mirror => mirror_unit(value)
    PaintShaderSpread::Decal =>
      if value >= 0.0 && value <= 1.0 {
        value
      } else {
        -1.0
      }
  }
}

///|
fn linear_gradient_t(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  x : Double,
  y : Double,
  spread : PaintShaderSpread,
) -> Double {
  let dx = x1 - x0
  let dy = y1 - y0
  let length_sq = dx * dx + dy * dy
  if length_sq > 0.000000001 {
    apply_shader_spread(((x - x0) * dx + (y - y0) * dy) / length_sq, spread)
  } else {
    0.0
  }
}

///|
fn radial_gradient_t(
  cx : Double,
  cy : Double,
  radius : Double,
  x : Double,
  y : Double,
  spread : PaintShaderSpread,
) -> Double {
  let dx = x - cx
  let dy = y - cy
  if radius > 0.000000001 {
    apply_shader_spread((dx * dx + dy * dy).sqrt() / radius, spread)
  } else {
    0.0
  }
}

///|
fn sweep_gradient_t(
  cx : Double,
  cy : Double,
  start_angle : Double,
  sweep_angle : Double,
  x : Double,
  y : Double,
  spread : PaintShaderSpread,
) -> Double {
  let start = normalize_sweep_gradient_start_angle(start_angle)
  let sweep = normalize_sweep_gradient_sweep_angle(sweep_angle)
  let angle = @math.atan2(y - cy, x - cx)
  if sweep != 0.0 {
    apply_shader_spread(
      sweep_relative_angle(angle, start, sweep) / sweep,
      spread,
    )
  } else {
    0.0
  }
}

///|
fn copy_gradient_stops(
  stops : Array[PaintGradientStop],
) -> Array[PaintGradientStop] {
  let copied = []
  for stop in stops {
    copied.push(PaintGradientStop::new(offset=stop.offset, color=stop.color))
  }
  copied
}

///|
fn two_gradient_stops(
  start_color : Color,
  end_color : Color,
) -> Array[PaintGradientStop] {
  [
    PaintGradientStop::new(offset=0.0, color=start_color),
    PaintGradientStop::new(offset=1.0, color=end_color),
  ]
}

///|
fn normalize_gradient_stop_offset(offset : Double) -> Double {
  guard offset == offset else { return 0.0 }
  clamp_unit(offset)
}

///|
fn sample_gradient_stops(stops : Array[PaintGradientStop], t : Double) -> Color {
  guard stops.length() > 0 else { return Color::transparent() }
  guard t >= 0.0 else { return Color::transparent() }
  let value = clamp_unit(t)
  let mut lower : PaintGradientStop? = None
  let mut upper : PaintGradientStop? = None
  for stop in stops {
    let offset = stop.offset
    if offset <= value {
      lower = match lower {
        Some(existing) if existing.offset > offset => Some(existing)
        _ => Some(stop)
      }
    }
    if offset >= value {
      upper = match upper {
        Some(existing) if existing.offset <= offset => Some(existing)
        _ => Some(stop)
      }
    }
  }
  match (lower, upper) {
    (Some(start), Some(end)) =>
      if start.offset == end.offset {
        end.color
      } else {
        lerp_color(
          start.color,
          end.color,
          (value - start.offset) / (end.offset - start.offset),
        )
      }
    (Some(start), None) => start.color
    (None, Some(end)) => end.color
    (None, None) => Color::transparent()
  }
}

///|
fn lerp_gradient_color(start : Color, end : Color, t : Double) -> Color {
  guard t >= 0.0 else { return Color::transparent() }
  lerp_color(start, end, t)
}

///|
fn lerp_color(start : Color, end : Color, t : Double) -> Color {
  Color::new(
    r=lerp_byte(start.r, end.r, t),
    g=lerp_byte(start.g, end.g, t),
    b=lerp_byte(start.b, end.b, t),
    a=lerp_byte(start.a, end.a, t),
  )
}

///|
fn repeat_unit(value : Double) -> Double {
  value - @math.floor(value)
}

///|
fn mirror_unit(value : Double) -> Double {
  let repeated = value - @math.floor(value / 2.0) * 2.0
  if repeated <= 1.0 {
    repeated
  } else {
    2.0 - repeated
  }
}

///|
fn lerp_byte(start : Byte, end : Byte, t : Double) -> Byte {
  let start_value = start.to_int().to_double()
  let end_value = end.to_int().to_double()
  clamp_byte((start_value + (end_value - start_value) * t + 0.5).to_int())
}
