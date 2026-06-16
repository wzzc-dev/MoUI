///|
pub fn[Msg] button(
  text : String,
  on_click? : Msg,
  variant? : ButtonVariant = ButtonVariant::Primary,
  theme? : @core.Theme = @core.Theme::default(),
  style? : @core.ButtonStyle,
  width? : Double = 100.0,
  height? : Double = 44.0,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => variant.style(theme)
  }
  let normal = resolved_style.normal
  let hovered = resolved_style.hovered
  let pressed = resolved_style.pressed
  @widget.button(
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

///|
pub fn[Msg] shortcut_button(
  label : String,
  on_click~ : Msg,
  shortcut~ : KeyboardShortcut,
  variant? : ButtonVariant = ButtonVariant::Primary,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 200.0,
  height? : Double = 44.0,
  shortcut_width? : Double = 76.0,
) -> @core.View[Msg] {
  let spacing = theme.spacing_scale.xs
  let button_width = views_max_double(72.0, width - shortcut_width - spacing)
  let shortcut_label = shortcut.display_label()
  row(
    [
      button(label, on_click~, variant~, theme~, width=button_width, height~),
      surface(
        text(
          shortcut_label,
          role=TextRole::Mono,
          theme~,
          width=views_max_double(24.0, shortcut_width - 12.0),
          height=views_max_double(16.0, height - 12.0),
        ).foreground(theme.palette.muted),
        width=shortcut_width,
        height~,
        variant=SurfaceVariant::Base,
        theme~,
        padding=6.0,
      )
      .semantics_role(@core.SemanticsRole::Text)
      .accessibility_label("Shortcut: " + shortcut_label),
    ],
    spacing~,
    align=CrossAlign::Center,
  )
  .keyboard_shortcut(shortcut)
  .semantics_description("Shortcut " + shortcut_label)
  .accessibility_label(label + ", shortcut " + shortcut_label)
}
