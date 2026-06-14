///|
pub fn[Msg] image(
  source : String,
  width? : Double,
  height? : Double,
  opacity? : Double = 1.0,
  corner_radius? : Double = 0.0,
  fit? : @core.ImageFit = @core.ImageFit::Contain,
) -> @core.View[Msg] {
  let size = match (width, height) {
    (Some(width), Some(height)) => Some(@core.Size::new(width~, height~))
    _ => None
  }
  @core.View::primitive_image_view(
    source~,
    size~,
    opacity~,
    corner_radius~,
    fit~,
  )
}
