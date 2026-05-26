///|
pub fn image(
  source : String,
  width? : Double,
  height? : Double,
  opacity? : Double = 1.0,
  corner_radius? : Double = 0.0,
  fit? : @core.ImageFit = @core.ImageFit::Contain,
) -> @core.ViewSpec {
  let size = match (width, height) {
    (Some(width), Some(height)) => Some(@core.Size::new(width~, height~))
    _ => None
  }
  @core.ViewSpec::ImageSpec({
    key: None,
    source,
    size,
    opacity,
    corner_radius,
    fit,
  })
}
