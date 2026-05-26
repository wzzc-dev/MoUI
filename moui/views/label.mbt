///|
pub fn text(
  text : String,
  role? : TextRole = TextRole::Body,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 160.0,
  height? : Double = 32.0,
) -> @core.ViewSpec {
  @core.ViewSpec::TextSpec({
    key: None,
    text,
    size: @core.Size::new(width~, height~),
    font: role.font(theme),
    color: role.color(theme),
  })
}
