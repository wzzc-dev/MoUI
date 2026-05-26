///|
pub fn surface(
  child : @core.ViewSpec,
  width? : Double,
  height? : Double,
  background? : @core.Color,
  corner_radius? : Double = 0.0,
  variant? : SurfaceVariant = SurfaceVariant::Base,
  theme? : @core.Theme = @core.Theme::default(),
  padding? : Double,
) -> @core.ViewSpec {
  let size = match (width, height) {
    (Some(width), Some(height)) => Some(@core.Size::new(width~, height~))
    _ => None
  }
  let style = variant.style(theme)
  let child_padding = match padding {
    Some(value) => @core.Insets::all(value)
    None => style.padding
  }
  let (background, corner_radius, child) = match background {
    Some(color) =>
      (
        Some(@core.Brush::solid(color)),
        corner_radius,
        @core.ViewSpec::PaddingSpec({ key: None, insets: child_padding, child }),
      )
    None =>
      (
        Some(style.brush),
        style.radius,
        @core.ViewSpec::PaddingSpec({ key: None, insets: child_padding, child }),
      )
  }
  @core.ViewSpec::ContainerSpec({
    key: None,
    size,
    background,
    border: style.border,
    corner_radius,
    shadow: style.shadow,
    child: Some(child),
  })
}

///|
pub fn empty() -> @core.ViewSpec {
  @core.ViewSpec::EmptySpec
}

///|
pub fn spacer(
  min_length? : Double = 0.0,
  weight? : Double = 1.0,
) -> @core.ViewSpec {
  @core.ViewSpec::SpacerSpec({ key: None, min_length, weight })
}
