///|
pub fn[Msg] surface(
  child : @core.View[Msg],
  width? : Double,
  height? : Double,
  background? : @core.Color,
  corner_radius? : Double = 0.0,
  variant? : SurfaceVariant = SurfaceVariant::Base,
  theme? : @core.Theme = @core.Theme::default(),
  padding? : Double,
) -> @core.View[Msg] {
  let size = match (width, height) {
    (Some(width), Some(height)) => Some(@core.Size::new(width~, height~))
    _ => None
  }
  let style = variant.style(theme)
  let child_padding = match padding {
    Some(value) => @core.Insets::all(value)
    None => style.padding
  }
  let (background, corner_radius) = match background {
    Some(color) => (Some(@core.Brush::solid(color)), corner_radius)
    None => (Some(style.brush), style.radius)
  }
  @core.View::container(
    child=Some(@core.View::padding_insets(child~, insets=child_padding)),
    size~,
    background~,
    border=style.border,
    corner_radius~,
    shadow=style.shadow,
  )
}

///|
pub fn[Msg] empty() -> @core.View[Msg] {
  @core.View::empty()
}

///|
pub fn[Msg] spacer(
  min_length? : Double = 0.0,
  weight? : Double = 1.0,
) -> @core.View[Msg] {
  @core.View::spacer(min_length~, weight~)
}
