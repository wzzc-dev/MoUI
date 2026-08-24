///|
pub fn[Msg] menu_bar(
  menus : Array[MenuItem[Msg]],
  active? : String = "",
  theme? : @core.Theme,
  width? : Double = 520.0,
  height? : Double = 42.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let items : Array[@core.View[Msg]] = []
  for item in menus {
    let selected = item.id == active
    items.push(
      @button.button(
        item.label,
        on_click=item.message,
        variant=if selected {
          @style.ButtonVariant::Tonal
        } else {
          @style.ButtonVariant::Ghost
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
  @container.container(
    @layout.row(
      items,
      spacing=resolved_theme.spacing_scale.xs,
      align=@style.CrossAlign::Center,
    ),
    width~,
    height~,
    variant=@style.ContainerVariant::Base,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.xs,
  )
  .semantics_role(@core.SemanticsRole::Menu)
  .accessibility_label("Menu bar")
}

///|
pub fn[Msg] command_menu(
  sections : Array[CommandMenuSection],
  on_select~ : (@core.CommandIntent) -> Msg,
  theme? : @core.Theme,
  width? : Double = 320.0,
  max_height? : Double = 280.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let rows : Array[@core.View[Msg]] = []
  for section in sections {
    if section.title != "" {
      rows.push(
        @text.text(
          section.title,
          role=@style.TextRole::Caption,
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
  // Floating menus lift with the component-theme overlay shadow when the
  // design system supplies one (Fluent flyout = shadow16), falling back to the
  // neutral large elevation shadow.
  .shadow(
    @style.views_ambient_control_theme(resolved_theme).surface.overlay_shadow.unwrap_or(
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
  let resolved_theme = @common.views_ambient_theme(theme)
  let content = if visible {
    @layout.stack([
      child,
      @container.container(
        menu,
        variant=@style.ContainerVariant::Overlay,
        theme=resolved_theme,
        padding=0.0,
      )
      // Context menus float above their host, so lift them with the component
      // overlay shadow (Fluent flyout) or the neutral large elevation shadow.
      .shadow(
        @style.views_ambient_control_theme(resolved_theme).surface.overlay_shadow.unwrap_or(
          resolved_theme.shadow_scale.lg,
        ),
      ),
    ])
    .semantics_role(@core.SemanticsRole::Menu)
    .align(alignment=@core.Alignment::bottom_trailing())
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
  command : @core.ActionCommand,
  on_select~ : (@core.CommandIntent) -> Msg,
  theme~ : @core.Theme,
  width~ : Double,
) -> @core.View[Msg] {
  let shortcut = command.shortcut_label()
  let label_width = @common.view_max_double(110.0, width - 96.0)
  let row_view = @layout.row(
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
        width=88.0,
        height=24.0,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@style.CrossAlign::Center,
  )
  @layout.stack([
    @button.button(
      "",
      on_click=on_select(command.intent),
      variant=@style.ButtonVariant::Ghost,
      theme~,
      width~,
      height=34.0,
    ),
    row_view,
  ])
  .disabled(disabled=!command.enabled)
  .accessibility_label(command.display_label())
}

///|
fn menu_command_item_width(label : String) -> Double {
  @common.view_max_double(
    58.0,
    label.to_array().length().to_double() * 8.0 + 24.0,
  )
}
