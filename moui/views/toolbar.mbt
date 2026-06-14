///|
pub fn[Msg] toolbar(
  children : Array[@core.View[Msg]],
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
  height? : Double = 48.0,
) -> @core.View[Msg] {
  surface(
    row(children, spacing=theme.spacing_scale.sm, align=CrossAlign::Center),
    width~,
    height~,
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.xs,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] button_group(
  items : Array[MenuItem[Msg]],
  selected? : String = "",
  theme? : @core.Theme = @core.Theme::default(),
  button_width? : Double = 88.0,
  height? : Double = 36.0,
) -> @core.View[Msg] {
  let buttons : Array[@core.View[Msg]] = []
  for item in items {
    let variant = if item.id == selected {
      ButtonVariant::Primary
    } else {
      ButtonVariant::Outline
    }
    buttons.push(
      button(
        item.label,
        on_click=item.message,
        variant~,
        theme~,
        width=button_width,
        height~,
      )
      .disabled(disabled=!item.enabled)
      .semantics_selected(selected=item.id == selected),
    )
  }
  row(buttons, spacing=0.0, align=CrossAlign::Center).semantics_role(
    @core.SemanticsRole::ButtonGroup,
  )
}

///|
pub fn[Msg] command_bar(
  items : Array[MenuItem[Msg]],
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
  height? : Double = 48.0,
) -> @core.View[Msg] {
  let commands : Array[@core.View[Msg]] = []
  for item in items {
    commands.push(
      button(
        item.label,
        on_click=item.message,
        variant=ButtonVariant::Ghost,
        theme~,
        width=command_item_width(item.label),
        height=36.0,
      ).disabled(disabled=!item.enabled),
    )
  }
  toolbar(commands, theme~, width~, height~)
}

///|
pub fn[Msg] command_palette(
  commands : Array[@core.ActionCommand],
  query? : String = "",
  on_select~ : (@core.CommandIntent) -> Msg,
  theme? : @core.Theme = @core.Theme::default(),
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
pub fn[Msg] status_bar(
  items : Array[String],
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
  height? : Double = 30.0,
) -> @core.View[Msg] {
  let segments : Array[@core.View[Msg]] = []
  for item in items {
    segments.push(
      text(
        item,
        role=TextRole::Caption,
        theme~,
        width=command_item_width(item),
        height=22.0,
      ),
    )
  }
  surface(
    row(segments, spacing=theme.spacing_scale.sm, align=CrossAlign::Center),
    width~,
    height~,
    background=theme.palette.surface_variant.multiply_alpha(0.52),
    corner_radius=theme.radius_scale.sm,
    theme~,
    padding=theme.spacing_scale.xs,
  ).semantics_role(@core.SemanticsRole::Group)
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

///|
fn command_item_width(label : String) -> Double {
  views_max_double(54.0, label.to_array().length().to_double() * 8.0 + 24.0)
}
