///|
pub fn[Msg] sidebar(
  title : String,
  items : Array[SidebarItem[Msg]],
  selected~ : String,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 240.0,
  height? : Double = 320.0,
) -> @core.View[Msg] {
  let inner_width = views_max_double(96.0, width - theme.spacing_scale.md * 2.0)
  let rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=inner_width, height=28.0),
  ]
  for item in items {
    let variant = if item.id == selected {
      ButtonVariant::Primary
    } else {
      ButtonVariant::Ghost
    }
    rows.push(
      button(
        item.label,
        on_click=item.message,
        variant~,
        theme~,
        width=inner_width,
        height=34.0,
      )
      .disabled(disabled=!item.enabled)
      .semantics_selected(selected=item.id == selected)
      .key("sidebar-item-" + item.id),
    )
  }
  surface(
    column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Start),
    width~,
    height~,
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.md,
  ).semantics_role(@core.SemanticsRole::List)
}
