///|
pub fn surface(
  child : @core.ViewSpec,
  width? : Double,
  height? : Double,
  background? : @core.Color,
  corner_radius? : Double = 0.0,
  style? : @core.SurfaceStyle,
) -> @core.ViewSpec {
  let size = match (width, height) {
    (Some(width), Some(height)) => Some(@core.Size::new(width~, height~))
    _ => None
  }
  let (background, corner_radius, child) = match style {
    Some(surface_style) =>
      (
        Some(surface_style.brush),
        surface_style.radius,
        @core.ViewSpec::PaddingSpec({
          key: None,
          insets: surface_style.padding,
          child,
        }),
      )
    None =>
      (background.map(color => @core.Brush::solid(color)), corner_radius, child)
  }
  let (border, shadow) = match style {
    Some(surface_style) => (surface_style.border, surface_style.shadow)
    None => (None, None)
  }
  @core.ViewSpec::ContainerSpec({
    key: None,
    size,
    background,
    border,
    corner_radius,
    shadow,
    child: Some(child),
  })
}

///|
pub fn spacer(
  min_length? : Double = 0.0,
  weight? : Double = 1.0,
) -> @core.ViewSpec {
  @core.ViewSpec::SpacerSpec({ key: None, min_length, weight })
}
