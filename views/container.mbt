///|
pub fn surface(
  child : @core.ViewSpec,
  width? : Double,
  height? : Double,
  background? : @core.Color,
  corner_radius? : Double = 0.0,
) -> @core.ViewSpec {
  let size = match (width, height) {
    (Some(width), Some(height)) => Some(@core.Size::new(width~, height~))
    _ => None
  }
  @core.ViewSpec::ContainerSpec({
    key: None,
    size,
    background,
    corner_radius,
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
