///|
pub fn[Msg] route_header(
  title : String,
  subtitle? : String = "",
  actions? : Array[ActionItem[Msg]] = [],
  theme? : @core.Theme = default_theme(),
  width? : Double = 520.0,
) -> @core.View[Msg] {
  let padding = theme.spacing_scale.md
  let content_width = views_max_double(120.0, width - padding * 2.0)
  let mut actions_width = 0.0
  for action in actions {
    actions_width = actions_width + route_header_action_width(action.label)
  }
  if actions.length() > 1 {
    actions_width = actions_width +
      theme.spacing_scale.xs * (actions.length() - 1).to_double()
  }
  let title_width = views_max_double(
    120.0,
    content_width - actions_width - theme.spacing_scale.md,
  )
  let title_rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=title_width, height=28.0),
  ]
  if subtitle != "" {
    title_rows.push(
      text(
        subtitle,
        role=TextRole::Caption,
        theme~,
        width=title_width,
        height=24.0,
      ),
    )
  }
  let action_buttons : Array[@core.View[Msg]] = []
  for action in actions {
    action_buttons.push(
      button(
        action.label,
        on_click=action.message,
        variant=ButtonVariant::Tonal,
        theme~,
        width=route_header_action_width(action.label),
        height=34.0,
      ).disabled(disabled=!action.enabled),
    )
  }
  let children : Array[@core.View[Msg]] = [
    column(title_rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
  ]
  if action_buttons.length() > 0 {
    children.push(
      row(
        action_buttons,
        spacing=theme.spacing_scale.xs,
        align=CrossAlign::Center,
      ),
    )
  }
  container(
    row(
      children,
      spacing=theme.spacing_scale.md,
      justify=MainAlign::Between,
      align=CrossAlign::Center,
    ),
    width~,
    height=if subtitle == "" { 58.0 } else { 78.0 },
    variant=ContainerVariant::Base,
    theme~,
    padding~,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label(title)
}

///|
fn route_header_action_width(label : String) -> Double {
  views_max_double(76.0, label.to_array().length().to_double() * 8.0 + 24.0)
}
