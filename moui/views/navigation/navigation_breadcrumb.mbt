///|
pub fn[Msg] breadcrumb(
  items : Array[BreadcrumbItem[Msg]],
  theme? : @core.Theme,
  spacing? : Double = @style.default_theme().spacing_scale.xs,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let children : Array[@core.View[Msg]] = []
  for index, item in items {
    if index > 0 {
      children.push(
        @text.text(
          "/",
          role=@style.TextRole::Caption,
          theme=resolved_theme,
          width=14.0,
          height=28.0,
        ),
      )
    }
    let child : @core.View[Msg] = match item.message {
      Some(message) =>
        @button.button(
          item.label,
          on_click=message,
          variant=@style.ButtonVariant::Ghost,
          theme=resolved_theme,
          width=breadcrumb_item_width(item.label),
          height=30.0,
        )
      None =>
        @text.text(
          item.label,
          role=@style.TextRole::Control,
          theme=resolved_theme,
          width=breadcrumb_item_width(item.label),
          height=30.0,
        )
    }
    children.push(child.key("breadcrumb-item-" + item.id))
  }
  @layout.row(children, spacing~, align=@style.CrossAlign::Center).semantics_role(
    @core.SemanticsRole::Group,
  )
}

///|
fn breadcrumb_item_width(label : String) -> Double {
  @common.view_max_double(
    42.0,
    label.to_array().length().to_double() * 8.0 + 24.0,
  )
}
