///|
pub fn[Msg] sidebar(
  title : String,
  items : Array[SidebarItem[Msg]],
  selected~ : String,
  theme? : @core.Theme,
  width? : Double = 240.0,
  height? : Double = 320.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let inner_width = @common.view_max_double(
    96.0,
    width - resolved_theme.spacing_scale.md * 2.0,
  )
  let rows : Array[@core.View[Msg]] = [
    @text.text(
      title,
      role=@style.TextRole::Control,
      theme=resolved_theme,
      width=inner_width,
      height=28.0,
    ),
  ]
  for item in items {
    let variant = if item.id == selected {
      @style.ButtonVariant::Primary
    } else {
      @style.ButtonVariant::Ghost
    }
    rows.push(
      @button.button(
        item.label,
        on_click=item.message,
        variant~,
        theme=resolved_theme,
        width=inner_width,
        height=34.0,
      )
      .disabled(disabled=!item.enabled)
      .semantics_selected(selected=item.id == selected)
      .key("sidebar-item-" + item.id),
    )
  }
  @container.container(
    @layout.column(
      rows,
      spacing=resolved_theme.spacing_scale.sm,
      align=@style.CrossAlign::Start,
    ),
    width~,
    height~,
    variant=@style.ContainerVariant::Base,
    theme=resolved_theme,
    padding=resolved_theme.spacing_scale.md,
  ).semantics_role(@core.SemanticsRole::List)
}
