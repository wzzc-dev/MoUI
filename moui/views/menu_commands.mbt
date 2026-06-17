///|
pub using @core {type ActionCommand}

///|
pub using @core {type ActionCommandMap}

///|
pub using @core {type CommandBinding}

///|
pub using @core {type CommandIntent}

///|
pub using @core {type KeyModifiers}

///|
pub using @core {type KeyboardShortcut}

///|
pub fn[Msg] menu_bar(
  menus : Array[MenuItem[Msg]],
  active? : String = "",
  theme? : @core.Theme = default_theme(),
  width? : Double = 520.0,
  height? : Double = 42.0,
) -> @core.View[Msg] {
  let items : Array[@core.View[Msg]] = []
  for item in menus {
    let selected = item.id == active
    items.push(
      button(
        item.label,
        on_click=item.message,
        variant=if selected {
          ButtonVariant::Tonal
        } else {
          ButtonVariant::Ghost
        },
        theme~,
        width=menu_command_item_width(item.label),
        height=34.0,
      )
      .disabled(disabled=!item.enabled)
      .semantics_role(@core.SemanticsRole::Menu)
      .semantics_selected(selected~),
    )
  }
  surface(
    row(items, spacing=theme.spacing_scale.xs, align=CrossAlign::Center),
    width~,
    height~,
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.xs,
  )
  .semantics_role(@core.SemanticsRole::Menu)
  .accessibility_label("Menu bar")
}

///|
pub fn[Msg] command_menu(
  sections : Array[CommandMenuSection],
  on_select~ : (CommandIntent) -> Msg,
  theme? : @core.Theme = default_theme(),
  width? : Double = 320.0,
  max_height? : Double = 280.0,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = []
  for section in sections {
    if section.title != "" {
      rows.push(
        text(
          section.title,
          role=TextRole::Caption,
          theme~,
          width=width - theme.spacing_scale.md * 2.0,
          height=22.0,
        ),
      )
    }
    for command in section.commands {
      rows.push(
        command_menu_row(
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
  )
  .semantics_role(@core.SemanticsRole::Menu)
  .accessibility_label("Command menu")
}

///|
pub fn[Msg] context_menu_region(
  child~ : @core.View[Msg],
  menu~ : @core.View[Msg],
  visible~ : Bool,
  theme? : @core.Theme = default_theme(),
) -> @core.View[Msg] {
  let content = if visible {
    overlay(
      child,
      surface(menu, variant=SurfaceVariant::Overlay, theme~, padding=0.0)
      .semantics_role(@core.SemanticsRole::Menu)
      .align(alignment=@core.Alignment::bottom_trailing()),
    )
  } else {
    child
  }
  content
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label("Context menu region")
  .semantics_description("Context menu region")
  .semantics_expanded(expanded=visible)
  .semantics_action(
    if visible {
      @core.SemanticsAction::Collapse
    } else {
      @core.SemanticsAction::Expand
    },
  )
}

///|
fn[Msg] command_menu_row(
  command : ActionCommand,
  on_select~ : (CommandIntent) -> Msg,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[Msg] {
  let shortcut = command.shortcut_label()
  let label_width = views_max_double(110.0, width - 96.0)
  let row_view = row(
    [
      text(
        command.display_label(),
        role=TextRole::Control,
        theme~,
        width=label_width,
        height=24.0,
      ),
      text(shortcut, role=TextRole::Mono, theme~, width=88.0, height=24.0),
    ],
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Center,
  )
  overlay(
    button(
      "",
      on_click=on_select(command.intent),
      variant=ButtonVariant::Ghost,
      theme~,
      width~,
      height=34.0,
    ),
    row_view,
  )
  .disabled(disabled=!command.enabled)
  .accessibility_label(command.display_label())
}

///|
fn menu_command_item_width(label : String) -> Double {
  views_max_double(58.0, label.to_array().length().to_double() * 8.0 + 24.0)
}
