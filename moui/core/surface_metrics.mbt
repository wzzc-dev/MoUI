///|
/// Logical and physical dimensions of a presentation surface.
///
/// This is the neutral contract shared by window backends and renderers. The
/// scale factor is always positive; constructors normalize invalid values to
/// one so callers cannot accidentally divide by zero when converting input.
pub(all) struct SurfaceMetrics {
  logical_size : Size
  physical_size : Size
  scale_factor : Double
} derive(Eq, Debug, ToJson)

///|
pub fn SurfaceMetrics::new(
  logical_size~ : Size,
  physical_size~ : Size,
  scale_factor? : Double = 1.0,
) -> SurfaceMetrics {
  { logical_size, physical_size, scale_factor: normalize_scale(scale_factor) }
}

///|
pub fn SurfaceMetrics::from_logical(
  size~ : Size,
  scale_factor? : Double = 1.0,
) -> SurfaceMetrics {
  let scale_factor = normalize_scale(scale_factor)
  {
    logical_size: size,
    physical_size: Size::new(
      width=size.width * scale_factor,
      height=size.height * scale_factor,
    ),
    scale_factor,
  }
}

///|
pub fn SurfaceMetrics::logical_size(self : SurfaceMetrics) -> Size {
  self.logical_size
}

///|
pub fn SurfaceMetrics::physical_size(self : SurfaceMetrics) -> Size {
  self.physical_size
}

///|
pub fn SurfaceMetrics::scale_factor(self : SurfaceMetrics) -> Double {
  self.scale_factor
}

///|
fn normalize_scale(scale_factor : Double) -> Double {
  if scale_factor > 0.0 {
    scale_factor
  } else {
    1.0
  }
}
