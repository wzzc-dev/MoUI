///|
pub fn[Msg] text(
  text : String,
  role? : TextRole = TextRole::Body,
  theme? : @core.Theme = default_theme(),
  width? : Double = 160.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  @widget.text(
    text~,
    size=@core.Size::new(width~, height~),
    font=role.font(theme),
    color=role.color(theme),
  )
}
