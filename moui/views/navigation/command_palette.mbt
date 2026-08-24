///|
pub fn[Msg] command_palette(
  commands : Array[@core.ActionCommand],
  query? : String = "",
  on_select~ : (@core.CommandIntent) -> Msg,
  theme? : @core.Theme,
  width? : Double = 420.0,
  max_height? : Double = 260.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let rows : Array[@core.View[Msg]] = []
  for command in commands {
    if command_palette_matches(command, query) {
      rows.push(
        command_palette_row(
          command,
          on_select~,
          theme=resolved_theme,
          width=width - resolved_theme.spacing_scale.md * 2.0,
        ),
      )
    }
  }
  if rows.length() == 0 {
    rows.push(
      @text.text(
        "No commands",
        role=@style.TextRole::Caption,
        theme=resolved_theme,
        width=width - resolved_theme.spacing_scale.md * 2.0,
        height=28.0,
      ),
    )
  }
  @container.container(
    @controls.scroll_view(
      @layout.column(
        rows,
        spacing=resolved_theme.spacing_scale.xs,
        align=@style.CrossAlign::Start,
      ),
      width=width - resolved_theme.spacing_scale.md * 2.0,
      height=max_height - resolved_theme.spacing_scale.md * 2.0,
    ),
    width~,
    height=max_height,
    variant=@style.ContainerVariant::Overlay,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.md,
  )
  // Command palettes float over the whole window, so lift them with the
  // theme's large elevation shadow like a dialog/popover.
  .shadow(resolved_theme.shadow_scale.lg)
  .semantics_role(@core.SemanticsRole::Menu)
}

///|
fn[Msg] command_palette_row(
  command : @core.ActionCommand,
  on_select~ : (@core.CommandIntent) -> Msg,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[Msg] {
  let shortcut = command.shortcut_label()
  let meta = command_palette_meta(command)
  let label_width = @common.view_max_double(120.0, width - 112.0)
  let rows : Array[@core.View[Msg]] = [
    @layout.row(
      [
        @text.text(
          command.display_label(),
          role=@style.TextRole::Control,
          theme~,
          width=label_width,
          height=24.0,
        ),
        @text.text(
          shortcut,
          role=@style.TextRole::Mono,
          theme~,
          width=96.0,
          height=24.0,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=@style.CrossAlign::Center,
    ),
  ]
  if meta != "" {
    rows.push(
      @text.text(
        meta,
        role=@style.TextRole::Caption,
        theme~,
        width~,
        height=22.0,
      ),
    )
  }
  let base = @button.button(
    "",
    on_click=on_select(command.intent),
    variant=@style.ButtonVariant::Ghost,
    theme~,
    width~,
    height=if meta == "" { 36.0 } else { 58.0 },
  )
  @layout.stack([
    base,
    @layout.column(rows, spacing=0.0, align=@style.CrossAlign::Start),
  ])
  .disabled(disabled=!command.enabled)
  .accessibility_label(command.display_label())
}

///|
fn command_palette_meta(command : @core.ActionCommand) -> String {
  if command.group != "" && command.description != "" {
    command.group + " - " + command.description
  } else if command.group != "" {
    command.group
  } else {
    command.description
  }
}

///|
fn command_palette_matches(
  command : @core.ActionCommand,
  query : String,
) -> Bool {
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
