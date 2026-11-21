///|
pub fn[Msg] route_header(
  title : String,
  subtitle~ : String = "",
  actions~ : Array[ActionItem[Msg]] = [],
  theme? : @core.Theme,
  width~ : Double = 520.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let padding = resolved_theme.spacing_scale.md
  let content_width = @common.view_max_double(120.0, width - padding * 2.0)
  let mut actions_width = 0.0
  for action in actions {
    actions_width = actions_width + route_header_action_width(action.label)
  }
  if actions.length() > 1 {
    actions_width = actions_width +
      resolved_theme.spacing_scale.xs * (actions.length() - 1).to_double()
  }
  let title_width = @common.view_max_double(
    120.0,
    content_width - actions_width - resolved_theme.spacing_scale.md,
  )
  let title_rows : Array[@core.View[Msg]] = [
    @text.text(
      title,
      role=Control,
      theme=resolved_theme,
      width=title_width,
      height=28.0,
    ),
  ]
  if subtitle != "" {
    title_rows.push(
      @text.text(
        subtitle,
        role=Caption,
        theme=resolved_theme,
        width=title_width,
        height=24.0,
        // The subtitle is prose (route summary + badge), not a label. Without
        // wrapping it grows past the header's box and paints over the pane's
        // right edge at narrower widths.
        wrap=true,
      ),
    )
  }
  let action_buttons : Array[@core.View[Msg]] = []
  for action in actions {
    action_buttons.push(
      @button.button(
        action.label,
        on_click=action.message,
        variant=Tonal,
        theme=resolved_theme,
        width=route_header_action_width(action.label),
        height=34.0,
      ).disabled(disabled=!action.enabled),
    )
  }
  let children : Array[@core.View[Msg]] = [
    @layout.column(
      title_rows,
      spacing=resolved_theme.spacing_scale.xs,
      align=Start,
    ),
  ]
  if action_buttons.length() > 0 {
    children.push(
      @layout.row(
        action_buttons,
        spacing=resolved_theme.spacing_scale.xs,
        align=Center,
      ),
    )
  }
  @container.container(
    @layout.row(
      children,
      spacing=resolved_theme.spacing_scale.md,
      justify=Between,
      align=Center,
    ),
    width~,
    // No fixed height: the wrapped subtitle decides the header height. The
    // title/subtitle rows already provide the minimum height a short header
    // had at a fixed 58/78.
    variant=Base,
    theme=resolved_theme,
    padding~,
  )
  .semantics_role(Group)
  .accessibility_label(title)
}

///|
fn route_header_action_width(label : String) -> Double {
  @common.view_max_double(
    76.0,
    label.to_array().length().to_double() * 8.0 + 24.0,
  )
}
