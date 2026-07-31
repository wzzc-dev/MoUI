///|
pub using @button {button}

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
  let button_width = @common.view_max_double(
    72.0,
    width - shortcut_width - spacing,
  )
  let shortcut_label = shortcut.display_label()
  row(
    [
      button(label, on_click~, variant~, theme?, width=button_width, height~),
      container(
        text(
          shortcut_label,
          role=TextRole::Mono,
          theme?,
          width=@common.view_max_double(24.0, shortcut_width - 12.0),
          height=@common.view_max_double(16.0, height - 12.0),
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

///|
test "shortcut button creates a valid view with accessibility label" {
  let btn : @core.View[Unit] = shortcut_button(
    "Copy",
    on_click=(),
    shortcut=@core.KeyboardShortcut::new(
      key="c",
      modifiers=@core.KeyModifiers::new(meta=true),
    ),
    width=200.0,
    height=44.0,
  )
  // Shortcut button carries an accessibility label describing the action
  let info = btn.semantics()
  assert_true(info.label is Some(label) && label != "")
}
