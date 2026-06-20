///|
pub fn[Msg] breadcrumb(
  items : Array[BreadcrumbItem[Msg]],
  theme? : @core.Theme,
  spacing? : Double = default_theme().spacing_scale.xs,
) -> @core.View[Msg] {
  let resolved_theme = views_ambient_theme(theme)
  let children : Array[@core.View[Msg]] = []
  for index, item in items {
    if index > 0 {
      children.push(
        text(
          "/",
          role=TextRole::Caption,
          theme=resolved_theme,
          width=14.0,
          height=28.0,
        ),
      )
    }
    let child : @core.View[Msg] = match item.message {
      Some(message) =>
        button(
          item.label,
          on_click=message,
          variant=ButtonVariant::Ghost,
          theme=resolved_theme,
          width=breadcrumb_item_width(item.label),
          height=30.0,
        )
      None =>
        text(
          item.label,
          role=TextRole::Control,
          theme=resolved_theme,
          width=breadcrumb_item_width(item.label),
          height=30.0,
        )
    }
    children.push(child.key("breadcrumb-item-" + item.id))
  }
  row(children, spacing~, align=CrossAlign::Center).semantics_role(
    @core.SemanticsRole::Group,
  )
}

///|
fn breadcrumb_item_width(label : String) -> Double {
  views_max_double(42.0, label.to_array().length().to_double() * 8.0 + 24.0)
}
