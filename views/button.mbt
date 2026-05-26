///|
pub fn button(
  text : String,
  on_click? : @core.ClickHandler,
  variant? : ButtonVariant = ButtonVariant::Primary,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 180.0,
  height? : Double = 44.0,
) -> @core.ViewSpec {
  let style = variant.style(theme)
  let normal = style.normal
  let hovered = style.hovered
  let pressed = style.pressed
  @core.ViewSpec::ButtonSpec({
    key: None,
    text,
    size: @core.Size::new(width~, height~),
    font: theme.typography.control,
    foreground: normal.foreground,
    background: normal.background,
    hovered_background: hovered.background,
    pressed_background: pressed.background,
    border: normal.border,
    shadow: normal.shadow,
    corner_radius: normal.radius,
    on_click,
  })
}
