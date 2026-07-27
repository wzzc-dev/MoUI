///|
pub fn[Msg] progress(
  value : Double,
  width? : Double = 180.0,
  height? : Double = 8.0,
  theme? : @core.Theme,
  style? : ProgressStyle,
  foreground? : @core.Color,
  background? : @core.Color,
) -> @core.View[Msg] {
  let value = clamp_view_double(value, 0.0, 1.0)
  @core.View::from_node(Progress::{
    value,
    width,
    height,
    theme,
    style,
    foreground,
    background,
  })
}
