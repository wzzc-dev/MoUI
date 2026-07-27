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
  theme? : @core.Theme,
  width? : Double = 520.0,
  height? : Double = 42.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
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
        theme=resolved_theme,
        width=menu_command_item_width(item.label),
        height=34.0,
      )
      .disabled(disabled=!item.enabled)
      .semantics_role(@core.SemanticsRole::Menu)
      .semantics_selected(selected~),
    )
  }
  container(
    row(
      items,
      spacing=resolved_theme.spacing_scale.xs,
      align=CrossAlign::Center,
    ),
    width~,
    height~,
    variant=ContainerVariant::Base,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.xs,
  )
  .semantics_role(@core.SemanticsRole::Menu)
  .accessibility_label("Menu bar")
}

///|
pub fn[Msg] command_menu(
  sections : Array[CommandMenuSection],
  on_select~ : (CommandIntent) -> Msg,
  theme? : @core.Theme,
  width? : Double = 320.0,
  max_height? : Double = 280.0,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let rows : Array[@core.View[Msg]] = []
  for section in sections {
    if section.title != "" {
      rows.push(
        text(
          section.title,
          role=TextRole::Caption,
          theme=resolved_theme,
          width=width - resolved_theme.spacing_scale.md * 2.0,
          height=22.0,
        ),
      )
    }
    for command in section.commands {
      rows.push(
        command_menu_row(
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
      text(
        "No commands",
        role=TextRole::Caption,
        theme=resolved_theme,
        width=width - resolved_theme.spacing_scale.md * 2.0,
        height=28.0,
      ),
    )
  }
  container(
    scroll_view(
      column(
        rows,
        spacing=resolved_theme.spacing_scale.xs,
        align=CrossAlign::Start,
      ),
      width=width - resolved_theme.spacing_scale.md * 2.0,
      height=max_height - resolved_theme.spacing_scale.md * 2.0,
    ),
    width~,
    height=max_height,
    variant=ContainerVariant::Overlay,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.md,
  )
  // Floating menus lift with the component-theme overlay shadow when the
  // design system supplies one (Fluent flyout = shadow16), falling back to the
  // neutral large elevation shadow.
  .shadow(
    resolved_theme.components.surface.overlay_shadow.unwrap_or(
      resolved_theme.shadow_scale.lg,
    ),
  )
  .semantics_role(@core.SemanticsRole::Menu)
  .accessibility_label("Command menu")
}

///|
pub fn[Msg] context_menu_region(
  child~ : @core.View[Msg],
  menu~ : @core.View[Msg],
  visible~ : Bool,
  theme? : @core.Theme,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let content = if visible {
    overlay(
      child,
      container(
        menu,
        variant=ContainerVariant::Overlay,
        theme=resolved_theme,
        padding=0.0,
      )
      // Context menus float above their host, so lift them with the component
      // overlay shadow (Fluent flyout) or the neutral large elevation shadow.
      .shadow(
        resolved_theme.components.surface.overlay_shadow.unwrap_or(
          resolved_theme.shadow_scale.lg,
        ),
      )
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
