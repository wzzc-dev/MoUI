///|
pub fn[Msg] button(
  text : String,
  on_click? : Msg,
  variant? : ButtonVariant = ButtonVariant::Primary,
  theme? : @core.Theme,
  style? : ButtonStyle,
  icon? : IconName? = None,
  width? : Double = 100.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  // `width`/`height` act as minimums: the button measures its label (plus an
  // optional leading icon) and grows to fit the content with padding from the
  // theme scale. Theme/style are resolved ambient-ly inside `button_control`
  // (an explicit `theme?` overrides `ctx.environment.theme`, otherwise the
  // button tracks dark-mode/a11y/reduced-motion changes without a rebuild).
  button_control(
    text~,
    variant~,
    min_size=@core.Size::new(width~, height~),
    theme?,
    style?,
    leading_icon=icon,
    on_click~,
  )
}

///|
pub fn[Msg] shortcut_button(
  label : String,
  on_click~ : Msg,
  shortcut~ : KeyboardShortcut,
  variant? : ButtonVariant = ButtonVariant::Primary,
  theme? : @core.Theme,
  width? : Double = 200.0,
  height? : Double = 44.0,
  shortcut_width? : Double = 76.0,
) -> @core.View[Msg] {
  let resolved_theme = theme.unwrap_or(@core.Theme::neutral())
  let spacing = resolved_theme.spacing_scale.xs
  let button_width = views_max_double(72.0, width - shortcut_width - spacing)
  let shortcut_label = shortcut.display_label()
  row(
    [
      button(label, on_click~, variant~, theme?, width=button_width, height~),
      container(
        text(
          shortcut_label,
          role=TextRole::Mono,
          theme?,
          width=views_max_double(24.0, shortcut_width - 12.0),
          height=views_max_double(16.0, height - 12.0),
        ).foreground(resolved_theme.palette.muted),
        width=shortcut_width,
        height~,
        variant=ContainerVariant::Base,
        theme?,
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
