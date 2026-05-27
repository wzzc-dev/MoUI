///|
pub fn[Msg] button(
  text : String,
  on_click? : Msg,
  variant? : ButtonVariant = ButtonVariant::Primary,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 180.0,
  height? : Double = 44.0,
) -> @core.View[Msg] {
  let style = variant.style(theme)
  let normal = style.normal
  let hovered = style.hovered
  let pressed = style.pressed
  @core.View::button(
    text~,
    size=@core.Size::new(width~, height~),
    font=theme.typography.control,
    foreground=normal.foreground,
    background=normal.background,
    hovered_background=hovered.background,
    pressed_background=pressed.background,
    border=normal.border,
    shadow=normal.shadow,
    corner_radius=normal.radius,
    on_click~,
  )
}
