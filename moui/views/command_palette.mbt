///|
pub fn[Msg] command_palette(
  commands : Array[ActionCommand],
  query? : String = "",
  on_select~ : (CommandIntent) -> Msg,
  theme? : @core.Theme = default_theme(),
  width? : Double = 420.0,
  max_height? : Double = 260.0,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  for command in commands {
    if command_palette_matches(command, query) {
      rows.push(
        command_palette_row(
          command,
          on_select~,
          theme~,
          width=width - theme.spacing_scale.md * 2.0,
        ),
      )
    }
  }
  if rows.length() == 0 {
    rows.push(
      text(
        "No commands",
        role=TextRole::Caption,
        theme~,
        width=width - theme.spacing_scale.md * 2.0,
        height=28.0,
      ),
    )
  }
  surface(
    scroll_view(
      column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
      width=width - theme.spacing_scale.md * 2.0,
      height=max_height - theme.spacing_scale.md * 2.0,
    ),
    width~,
    height=max_height,
    variant=SurfaceVariant::Overlay,
    theme~,
    padding=theme.spacing_scale.md,
  ).semantics_role(@core.SemanticsRole::Menu)
}

///|
fn[Msg] command_palette_row(
  command : ActionCommand,
  on_select~ : (CommandIntent) -> Msg,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[Msg] {
  let shortcut = command.shortcut_label()
  let meta = command_palette_meta(command)
  let label_width = views_max_double(120.0, width - 112.0)
  let rows : Array[@core.View[Msg]] = [
    row(
      [
        text(
          command.display_label(),
          role=TextRole::Control,
          theme~,
          width=label_width,
          height=24.0,
        ),
        text(shortcut, role=TextRole::Mono, theme~, width=96.0, height=24.0),
      ],
      spacing=theme.spacing_scale.xs,
      align=CrossAlign::Center,
    ),
  ]
  if meta != "" {
    rows.push(text(meta, role=TextRole::Caption, theme~, width~, height=22.0))
  }
  let base = button(
    "",
    on_click=on_select(command.intent),
    variant=ButtonVariant::Ghost,
    theme~,
    width~,
    height=if meta == "" { 36.0 } else { 58.0 },
  )
  overlay(base, column(rows, spacing=0.0, align=CrossAlign::Start))
  .disabled(disabled=!command.enabled)
  .accessibility_label(command.display_label())
}

///|
fn command_palette_meta(command : ActionCommand) -> String {
  if command.group != "" && command.description != "" {
    command.group + " - " + command.description
  } else if command.group != "" {
    command.group
  } else {
    command.description
  }
}

///|
fn command_palette_matches(command : ActionCommand, query : String) -> Bool {
  if query == "" {
    true
  } else {
    let needle = query.to_lower()
    command.display_label().to_lower().contains(needle) ||
    command.group.to_lower().contains(needle) ||
    command.description.to_lower().contains(needle) ||
    command.shortcut_label().to_lower().contains(needle)
  }
}
